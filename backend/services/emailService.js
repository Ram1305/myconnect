// Email OTP Service
// This service handles sending OTP via Gmail SMTP

const nodemailer = require('nodemailer');

// Gmail SMTP Configuration from environment variables
const GMAIL_USER = process.env.GMAIL_USER;
const GMAIL_PASSWORD = process.env.GMAIL_PASSWORD; // Use App Password, not regular password
const GMAIL_FROM_NAME = process.env.GMAIL_FROM_NAME || 'My Connect';

// Create reusable transporter object using Gmail SMTP
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: GMAIL_USER,
    pass: GMAIL_PASSWORD
  }
});

// Verify transporter configuration
transporter.verify((error, success) => {
  if (error) {
    console.error('❌ Email service configuration error:', error);
    console.error('💡 Make sure GMAIL_USER and GMAIL_PASSWORD are set in .env file');
    console.error('💡 For Gmail, use App Password (not regular password)');
    console.error('💡 Enable 2-Step Verification and generate App Password from:');
    console.error('   https://myaccount.google.com/apppasswords');
  } else {
    console.log('✅ Email service is ready to send emails');
  }
});

// Store OTPs temporarily (in production, use Redis or similar)
const otpStore = new Map();

// Generate a random 6-digit OTP
const generateOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

// Send OTP via Email
const sendOTP = async (email, otp) => {
  try {
    if (!GMAIL_USER || !GMAIL_PASSWORD) {
      console.error('❌ Gmail credentials not configured');
      throw new Error('Email service not configured. Please set GMAIL_USER and GMAIL_PASSWORD in .env');
    }

    const mailOptions = {
      from: `"${GMAIL_FROM_NAME}" <${GMAIL_USER}>`,
      to: email,
      subject: 'Password Reset OTP - My Connect',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body {
              font-family: Arial, sans-serif;
              line-height: 1.6;
              color: #333;
              max-width: 600px;
              margin: 0 auto;
              padding: 20px;
            }
            .container {
              background-color: #f9f9f9;
              border-radius: 10px;
              padding: 30px;
              border: 1px solid #e0e0e0;
            }
            .header {
              text-align: center;
              margin-bottom: 30px;
            }
            .header h1 {
              color: #8B4513;
              margin: 0;
            }
            .otp-box {
              background-color: #fff;
              border: 2px solid #8B4513;
              border-radius: 8px;
              padding: 20px;
              text-align: center;
              margin: 30px 0;
            }
            .otp-code {
              font-size: 32px;
              font-weight: bold;
              color: #8B4513;
              letter-spacing: 5px;
              font-family: 'Courier New', monospace;
            }
            .message {
              background-color: #fff;
              padding: 20px;
              border-radius: 8px;
              margin: 20px 0;
            }
            .warning {
              background-color: #fff3cd;
              border-left: 4px solid #ffc107;
              padding: 15px;
              margin: 20px 0;
              border-radius: 4px;
            }
            .footer {
              text-align: center;
              margin-top: 30px;
              color: #666;
              font-size: 12px;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>My Connect</h1>
              <h2>Password Reset Request</h2>
            </div>
            
            <div class="message">
              <p>Hello,</p>
              <p>You have requested to reset your password for your My Connect account.</p>
              <p>Please use the following OTP (One-Time Password) to complete the password reset process:</p>
            </div>
            
            <div class="otp-box">
              <p style="margin: 0 0 10px 0; color: #666;">Your OTP Code:</p>
              <div class="otp-code">${otp}</div>
            </div>
            
            <div class="warning">
              <strong>⚠️ Important:</strong>
              <ul style="margin: 10px 0; padding-left: 20px;">
                <li>This OTP is valid for <strong>10 minutes</strong> only</li>
                <li>Do not share this OTP with anyone</li>
                <li>If you didn't request this, please ignore this email</li>
              </ul>
            </div>
            
            <div class="message">
              <p>If you didn't request a password reset, you can safely ignore this email. Your password will remain unchanged.</p>
            </div>
            
            <div class="footer">
              <p>This is an automated email. Please do not reply to this message.</p>
              <p>&copy; ${new Date().getFullYear()} My Connect. All rights reserved.</p>
            </div>
          </div>
        </body>
        </html>
      `,
      text: `
        My Connect - Password Reset OTP
        
        You have requested to reset your password.
        
        Your OTP Code: ${otp}
        
        This OTP is valid for 10 minutes only.
        Do not share this OTP with anyone.
        
        If you didn't request this, please ignore this email.
        
        © ${new Date().getFullYear()} My Connect
      `
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(`✅ Email OTP sent successfully to ${email}`);
    console.log(`   Message ID: ${info.messageId}`);
    return true;
  } catch (error) {
    console.error('❌ Error sending email OTP:', error);
    throw error;
  }
};

// Request OTP for password reset
const requestPasswordResetOTP = async (email) => {
  try {
    // Check if OTP was recently sent (prevent spam)
    const existingOTP = otpStore.get(email);
    if (existingOTP && Date.now() - existingOTP.timestamp < 60000) {
      return {
        success: false,
        message: 'Please wait 60 seconds before requesting another OTP'
      };
    }

    // Generate OTP
    const otp = generateOTP();

    // Send OTP via Email
    try {
      await sendOTP(email, otp);
    } catch (error) {
      console.error('Error sending OTP:', error);
      return {
        success: false,
        message: 'Failed to send OTP. Please check your email address and try again later.'
      };
    }

    // Store OTP with expiration (10 minutes)
    otpStore.set(email, {
      otp,
      timestamp: Date.now(),
      expiresAt: Date.now() + 10 * 60 * 1000 // 10 minutes
    });

    // Clean up expired OTPs
    setTimeout(() => {
      otpStore.delete(email);
    }, 10 * 60 * 1000);

    return {
      success: true,
      message: `OTP sent successfully to ${email}`
    };
  } catch (error) {
    console.error('Error requesting password reset OTP:', error);
    return {
      success: false,
      message: 'An error occurred. Please try again later.'
    };
  }
};

// Verify OTP
const verifyOTP = (email, otp) => {
  try {
    const storedOTP = otpStore.get(email);

    if (!storedOTP) {
      return {
        success: false,
        message: 'OTP not found or expired. Please request a new OTP.'
      };
    }

    // Check if OTP expired
    if (Date.now() > storedOTP.expiresAt) {
      otpStore.delete(email);
      return {
        success: false,
        message: 'OTP has expired. Please request a new OTP.'
      };
    }

    // Verify OTP
    if (storedOTP.otp !== otp) {
      return {
        success: false,
        message: 'Invalid OTP. Please try again.'
      };
    }

    // OTP verified successfully
    // Mark as verified (keep for password reset)
    otpStore.set(email, {
      ...storedOTP,
      verified: true
    });

    return {
      success: true,
      message: 'OTP verified successfully'
    };
  } catch (error) {
    console.error('Error verifying OTP:', error);
    return {
      success: false,
      message: 'An error occurred. Please try again.'
    };
  }
};

// Check if OTP is verified for password reset
const isOTPVerified = (email) => {
  const storedOTP = otpStore.get(email);
  return storedOTP && storedOTP.verified === true && Date.now() <= storedOTP.expiresAt;
};

// Clear OTP after password reset
const clearOTP = (email) => {
  otpStore.delete(email);
};

// Get OTP for testing purposes only (remove in production)
const getOTPForTesting = (email) => {
  const storedOTP = otpStore.get(email);
  return storedOTP ? storedOTP.otp : null;
};

module.exports = {
  requestPasswordResetOTP,
  verifyOTP,
  isOTPVerified,
  clearOTP,
  getOTPForTesting,
  otpStore // Expose for testing
};
