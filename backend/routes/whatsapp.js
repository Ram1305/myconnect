// WhatsApp Webhook Route
// Handles webhook callbacks from WhatsApp Business API for message status updates

const express = require('express');
const router = express.Router();

// Webhook verification (GET request)
router.get('/webhook', (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  // Verify token (set this in your WhatsApp Business API webhook settings)
  const VERIFY_TOKEN = process.env.WHATSAPP_VERIFY_TOKEN || 'your_verify_token_here';

  if (mode === 'subscribe' && token === VERIFY_TOKEN) {
    console.log('✅ WhatsApp webhook verified');
    res.status(200).send(challenge);
  } else {
    console.error('❌ WhatsApp webhook verification failed');
    res.sendStatus(403);
  }
});

// Webhook callback (POST request) - receives message status updates
router.post('/webhook', (req, res) => {
  const body = req.body;

  console.log('📨 WhatsApp webhook received:', JSON.stringify(body, null, 2));

  // Verify it's a WhatsApp Business Account webhook
  if (body.object === 'whatsapp_business_account') {
    body.entry?.forEach((entry) => {
      entry.changes?.forEach((change) => {
        if (change.field === 'messages') {
          const value = change.value;

          // Handle message status updates
          if (value.statuses) {
            value.statuses.forEach((status) => {
              console.log(`\n📊 Message Status Update:`);
              console.log(`   Message ID: ${status.id}`);
              console.log(`   Status: ${status.status}`);
              console.log(`   Recipient: ${status.recipient_id}`);
              console.log(`   Timestamp: ${new Date(parseInt(status.timestamp) * 1000).toISOString()}`);

              // Check for errors
              if (status.status === 'failed' && status.errors) {
                status.errors.forEach((error) => {
                  console.error(`\n❌ Message Delivery Failed:`);
                  console.error(`   Error Code: ${error.code}`);
                  console.error(`   Error Title: ${error.title}`);
                  console.error(`   Error Message: ${error.message}`);

                  // Handle specific error codes
                  if (error.code === 131049) {
                    console.error(`\n   ⚠️  ERROR 131049: Message blocked to maintain healthy ecosystem`);
                    console.error(`   💡 This usually means:`);
                    console.error(`      - Account is new and needs to build reputation`);
                    console.error(`      - Recipient hasn't engaged with your business`);
                    console.error(`      - Account quality score is low`);
                    console.error(`\n   💡 Solutions:`);
                    console.error(`      1. Wait 24-48 hours for account reputation to build`);
                    console.error(`      2. Have recipient message you first (opens 24-hour window)`);
                    console.error(`      3. Complete business verification`);
                    console.error(`      4. Use SMS/Email as fallback for OTP`);
                  }
                });
              } else if (status.status === 'delivered') {
                console.log(`   ✅ Message delivered successfully`);
              } else if (status.status === 'read') {
                console.log(`   ✅ Message read by recipient`);
              } else if (status.status === 'sent') {
                console.log(`   ✅ Message sent (awaiting delivery)`);
              }
            });
          }

          // Handle incoming messages (if any)
          if (value.messages) {
            value.messages.forEach((message) => {
              console.log(`\n📩 Incoming Message:`);
              console.log(`   From: ${message.from}`);
              console.log(`   Type: ${message.type}`);
              console.log(`   Message ID: ${message.id}`);
              // Handle incoming messages if needed
            });
          }
        }
      });
    });

    // Always return 200 to acknowledge receipt
    res.status(200).send('OK');
  } else {
    res.sendStatus(404);
  }
});

module.exports = router;

