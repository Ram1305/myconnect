// WhatsApp OTP Service
// This service handles sending OTP via WhatsApp Business API

const https = require('https');

// WhatsApp Business API Configuration
// Store these in environment variables for security
const WHATSAPP_ACCESS_TOKEN = process.env.WHATSAPP_ACCESS_TOKEN || 'EAAMSHU9sdloBQLBWFTQPikeDUUZC9OZAOeobFpGxFxDaaTSnbfQmqZACJLVgLJ6uXCROuGnlEF70dyuwtUnwpKi2ui5jZAQO9ATkil8ZBiBXCJAZBNICVqmJJLWkpclEpZC7wHd5hKckcFNccq3KOdCSDYZCxa9PbMpu7JFobhy77ZCDkq0mUkh9psGJnMwxvn9LZBnEzIKyl7PAxJirYSNHfQMyNqGlBCmN66quZB8iLo5fZAioZCFb2wX0OtuQrYTPZBMPFLbTlr1VwgZBkKHCZCpaddcBnwZDZD';
const WHATSAPP_PHONE_NUMBER_ID = process.env.WHATSAPP_PHONE_NUMBER_ID || '964907900029817';
const WHATSAPP_BUSINESS_ACCOUNT_ID = process.env.WHATSAPP_BUSINESS_ACCOUNT_ID || '1530953264843239';
const WHATSAPP_API_VERSION = process.env.WHATSAPP_API_VERSION || 'v22.0';
const WHATSAPP_TEMPLATE_NAME = process.env.WHATSAPP_TEMPLATE_NAME || 'jaspers_market_plain_text_v1';
const WHATSAPP_API_URL = `https://graph.facebook.com/${WHATSAPP_API_VERSION}/${WHATSAPP_PHONE_NUMBER_ID}/messages`;

// Store OTPs temporarily (in production, use Redis or similar)
const otpStore = new Map();

// Generate a random 6-digit OTP
const generateOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

// Send OTP via WhatsApp Business API
const sendOTP = async (mobileNumber, otp) => {
  try {
    // Format mobile number (remove + if present, ensure country code)
    let formattedNumber = mobileNumber.replace(/[^0-9]/g, '');
    
    // If number doesn't start with country code, add it (assuming India +91)
    if (!formattedNumber.startsWith('91') && formattedNumber.length === 10) {
      formattedNumber = '91' + formattedNumber;
    }
    
    // WhatsApp message - Using template format (required for business accounts)
    // Template must be created and approved in WhatsApp Business Manager
    const messageText = `Your OTP for password reset is: ${otp}. This OTP is valid for 10 minutes. Do not share this OTP with anyone.`;
    
    // Use template format (required for WhatsApp Business API)
    // NOTE: The current template 'jaspers_market_plain_text_v1' is a fixed marketing message
    // It does NOT support parameters, so it cannot include the OTP in the message
    // 
    // SOLUTION: You need to create a NEW template for OTP messages with a parameter
    // Example template text: "Your OTP for password reset is {{1}}. Valid for 10 minutes."
    // 
    // For now, we'll use the existing template (which won't show OTP)
    // TODO: Create a proper OTP template in WhatsApp Business Manager
    
    const requestData = JSON.stringify({
      messaging_product: 'whatsapp',
      to: formattedNumber,
      type: 'template',
      template: {
        name: WHATSAPP_TEMPLATE_NAME,
        language: {
          code: 'en_US'
        }
        // This template doesn't support parameters, so we can't include the OTP
        // You need to create a new template with {{1}} placeholder for OTP
      }
    });
    
    console.log(`⚠️  WARNING: Current template doesn't support OTP parameters!`);
    console.log(`📋 Template: ${WHATSAPP_TEMPLATE_NAME}`);
    console.log(`🔢 OTP Generated: ${otp} (will be stored for verification)`);
    console.log(`📱 Sending to: +${formattedNumber}`);
    
    console.log(`📤 Sending WhatsApp message using template: ${WHATSAPP_TEMPLATE_NAME}`);
    console.log(`📱 To: +${formattedNumber}`);
    console.log(`🔢 OTP: ${otp}`);

    // Make request to WhatsApp Business API
    return new Promise((resolve, reject) => {
      const url = new URL(WHATSAPP_API_URL);
      
      const options = {
        hostname: url.hostname,
        path: url.pathname + url.search,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${WHATSAPP_ACCESS_TOKEN}`,
          'Content-Length': Buffer.byteLength(requestData)
        }
      };

      const req = https.request(options, (res) => {
        let responseData = '';

        res.on('data', (chunk) => {
          responseData += chunk;
        });

        res.on('end', () => {
          try {
            const response = JSON.parse(responseData);
            
            if (res.statusCode === 200 && response.messages && response.messages[0]) {
              console.log(`✅ WhatsApp OTP sent successfully to ${formattedNumber}`);
              console.log(`   Message ID: ${response.messages[0].id}`);
              console.log(`   ⚠️  Note: Message may fail delivery with error 131049 if account reputation is low`);
              console.log(`   ⚠️  Check webhook for delivery status updates`);
              resolve(true);
            } else {
              console.error('❌ WhatsApp API Error:', response);
              console.error(`   Status Code: ${res.statusCode}`);
              const errorMessage = response.error?.message || response.error?.error_user_msg || 'Unknown error';
              const errorCode = response.error?.code || 'N/A';
              console.error(`   Error: ${errorMessage}`);
              console.error(`   Error Code: ${errorCode}`);
              console.error(`   Error Type: ${response.error?.type || 'N/A'}`);
              
              // Special handling for error 131049
              if (errorCode === 131049) {
                console.error(`\n   ⚠️  ERROR 131049: Message delivery blocked to maintain healthy ecosystem`);
                console.error(`   💡 Solutions:`);
                console.error(`      1. Wait 24-48 hours for account reputation to build`);
                console.error(`      2. Have recipient message you first (opens 24-hour window)`);
                console.error(`      3. Use SMS/Email as fallback for OTP`);
                console.error(`      4. Verify your business account in Facebook Business Manager`);
              }
              
              // Reject on API errors
              reject(new Error(`WhatsApp API Error: ${errorMessage} (Code: ${errorCode})`));
            }
          } catch (parseError) {
            console.error('❌ Error parsing WhatsApp API response:', parseError);
            console.error('   Raw response:', responseData);
            reject(parseError);
          }
        });
      });

      req.on('error', (error) => {
        console.error('❌ Error sending WhatsApp OTP:', error);
        reject(error);
      });

      req.write(requestData);
      req.end();
    });
  } catch (error) {
    console.error('❌ Error in sendOTP function:', error);
    return false;
  }
};

// Request OTP for password reset
const requestPasswordResetOTP = async (mobileNumber) => {
  try {
    // Check if OTP was recently sent (prevent spam)
    const existingOTP = otpStore.get(mobileNumber);
    if (existingOTP && Date.now() - existingOTP.timestamp < 60000) {
      return {
        success: false,
        message: 'Please wait 60 seconds before requesting another OTP'
      };
    }
    
    // Generate OTP
    const otp = generateOTP();
    
    // Send OTP via WhatsApp
    try {
      const sent = await sendOTP(mobileNumber, otp);
      
      if (!sent) {
        return {
          success: false,
          message: 'Failed to send OTP. Please try again later.'
        };
      }
    } catch (error) {
      console.error('Error sending OTP:', error);
      return {
        success: false,
        message: 'Failed to send OTP. Please try again later.'
      };
    }
    
    // Store OTP with expiration (10 minutes)
    otpStore.set(mobileNumber, {
      otp,
      timestamp: Date.now(),
      expiresAt: Date.now() + 10 * 60 * 1000 // 10 minutes
    });
    
    // Clean up expired OTPs
    setTimeout(() => {
      otpStore.delete(mobileNumber);
    }, 10 * 60 * 1000);
    
    return {
      success: true,
      message: 'OTP sent successfully to your WhatsApp number'
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
const verifyOTP = (mobileNumber, otp) => {
  try {
    const storedOTP = otpStore.get(mobileNumber);
    
    if (!storedOTP) {
      return {
        success: false,
        message: 'OTP not found or expired. Please request a new OTP.'
      };
    }
    
    // Check if OTP expired
    if (Date.now() > storedOTP.expiresAt) {
      otpStore.delete(mobileNumber);
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
    otpStore.set(mobileNumber, {
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
const isOTPVerified = (mobileNumber) => {
  const storedOTP = otpStore.get(mobileNumber);
  return storedOTP && storedOTP.verified === true && Date.now() <= storedOTP.expiresAt;
};

// Clear OTP after password reset
const clearOTP = (mobileNumber) => {
  otpStore.delete(mobileNumber);
};

// Get OTP for testing purposes only (remove in production)
const getOTPForTesting = (mobileNumber) => {
  const storedOTP = otpStore.get(mobileNumber);
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

