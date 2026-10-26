const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

/**
 * Configure your email transport provider (e.g., SendGrid, Resend, AWS SES, or SMTP).
 * You can set environment secrets via:
 * firebase functions:secrets:set SMTP_USER
 * firebase functions:secrets:set SMTP_PASS
 */
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || "smtp.gmail.com",
  port: parseInt(process.env.SMTP_PORT || "587"),
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

/**
 * Helper to securely hash OTP with salt
 */
function hashOtp(otp, salt) {
  return crypto.createHmac("sha256", salt).update(otp).digest("hex");
}

/**
 * Cloud Function: sendEmailOtp
 * - Rate-limits resends (at least 60s cooldown)
 * - Generates cryptographically secure 6-digit numeric OTP
 * - Hashes OTP before saving to Firestore (never stored plaintext)
 * - Sets 5-minute expiry
 * - Sends email to the user
 */
exports.sendEmailOtp = functions.https.onCall(async (data, context) => {
  const email = (data.email || "").trim().toLowerCase();
  const emailRegex = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

  if (!email || !emailRegex.test(email)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "A valid email address is required."
    );
  }

  const otpDocRef = db.collection("_email_otps").doc(email);
  const now = Date.now();

  const existing = await otpDocRef.get();
  if (existing.exists) {
    const prevData = existing.data();
    // Rate limit: must wait at least 60 seconds before sending another OTP
    if (prevData.createdAt && now - prevData.createdAt < 60 * 1000) {
      const waitSeconds = Math.ceil((60 * 1000 - (now - prevData.createdAt)) / 1000);
      throw new functions.https.HttpsError(
        "resource-exhausted",
        `Please wait ${waitSeconds}s before requesting a new code.`
      );
    }
  }

  // Generate cryptographically secure 6-digit code
  const otpCode = crypto.randomInt(100000, 999999).toString();
  const salt = crypto.randomBytes(16).toString("hex");
  const hashedOtp = hashOtp(otpCode, salt);

  // Expire in 5 minutes
  const expiresAt = now + 5 * 60 * 1000;

  await otpDocRef.set({
    hashedOtp,
    salt,
    createdAt: now,
    expiresAt,
    attempts: 0,
  });

  // If SMTP is not yet configured, log OTP to Cloud Functions console for testing
  if (!process.env.SMTP_USER || !process.env.SMTP_PASS) {
    console.log(`[FlowTake Auth] DEV MODE: Generated OTP for ${email}: ${otpCode}`);
    return { success: true, message: "Code generated (Check Functions log in development)" };
  }

  // Deliver email
  try {
    await transporter.sendMail({
      from: `"FlowTake" <${process.env.SMTP_USER}>`,
      to: email,
      subject: "Your FlowTake Verification Code",
      text: `Your FlowTake verification code is ${otpCode}. It expires in 5 minutes. If you did not request this code, please ignore this email.`,
      html: `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 500px; margin: 0 auto; padding: 32px 24px; background: #ffffff; border: 1px solid #e5e7eb; border-radius: 12px;">
          <h2 style="color: #111827; margin: 0 0 16px; font-size: 22px; font-weight: 700;">Your verification code</h2>
          <p style="color: #4b5563; font-size: 15px; margin: 0 0 24px;">Use the 6-digit code below to complete sign in to FlowTake:</p>
          <div style="background: #f3f4f6; padding: 18px; border-radius: 10px; text-align: center; font-size: 32px; font-weight: 800; letter-spacing: 6px; color: #111827;">
            ${otpCode}
          </div>
          <p style="color: #9ca3af; font-size: 13px; margin: 24px 0 0;">This code will expire in 5 minutes. If you didn't request it, you can safely ignore this email.</p>
        </div>
      `,
    });
  } catch (err) {
    console.error("Email delivery failed:", err);
    throw new functions.https.HttpsError(
      "internal",
      "Unable to send verification email. Please check SMTP configuration."
    );
  }

  return { success: true };
});

/**
 * Cloud Function: verifyEmailOtp
 * - Verifies attempts <= 5 to prevent brute force
 * - Verifies expiry (5 mins)
 * - Verifies constant-time hash comparison
 * - Deletes OTP on successful validation
 * - Creates/finds Firebase Auth user and issues custom token
 */
exports.verifyEmailOtp = functions.https.onCall(async (data, context) => {
  const email = (data.email || "").trim().toLowerCase();
  const otp = (data.otp || "").trim();

  if (!email || !otp || otp.length !== 6) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Email and 6-digit verification code are required."
    );
  }

  const otpDocRef = db.collection("_email_otps").doc(email);
  const snap = await otpDocRef.get();

  if (!snap.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "No verification code found for this email. Please request a new code."
    );
  }

  const record = snap.data();
  const now = Date.now();

  // Check expiration
  if (now > record.expiresAt) {
    await otpDocRef.delete();
    throw new functions.https.HttpsError(
      "deadline-exceeded",
      "This verification code has expired. Please request a new one."
    );
  }

  // Check brute force attempts (max 5)
  if (record.attempts >= 5) {
    await otpDocRef.delete();
    throw new functions.https.HttpsError(
      "permission-denied",
      "Too many failed attempts. Please request a new verification code."
    );
  }

  // Verify hash
  const computedHash = hashOtp(otp, record.salt);
  const isValid = crypto.timingSafeEqual(
    Buffer.from(computedHash, "hex"),
    Buffer.from(record.hashedOtp, "hex")
  );

  if (!isValid) {
    await otpDocRef.update({
      attempts: admin.firestore.FieldValue.increment(1),
    });
    const remaining = 4 - (record.attempts || 0);
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Invalid verification code. ${remaining > 0 ? `${remaining} attempts remaining.` : 'Code revoked.'}`
    );
  }

  // Successfully verified - revoke OTP immediately
  await otpDocRef.delete();

  // Find or create Firebase Auth user
  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      userRecord = await admin.auth().createUser({
        email: email,
        emailVerified: true,
      });
    } else {
      throw error;
    }
  }

  // Create Firebase Custom Token for the client to sign in
  const customToken = await admin.auth().createCustomToken(userRecord.uid);

  return { customToken };
});
