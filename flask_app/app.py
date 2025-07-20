from flask import Flask, request, jsonify
from twilio.rest import Client
from dotenv import load_dotenv
import os

load_dotenv()

account_sid = os.getenv('TWILIO_ACCOUNT_SID','')
auth_token = os.getenv('TWILIO_AUTH_TOKEN', '')
client = Client(account_sid, auth_token)

# Flask app
app = Flask(__name__)

# Fixed WhatsApp recipient
FROM_NUMBER = 'whatsapp:+14155238886'  # Twilio sandbox number

@app.route('/send', methods=['POST'])
def send_whatsapp():
    try:
        data = request.get_json()
        print(f"✅ Received request: {data}") # 👈 Log incoming request data

        message_text = data.get('message')
        mobile_number = data.get('mobile_number')

        if not message_text:
            return jsonify({'error': 'Missing message'}), 400
        
        if not mobile_number:
            return jsonify({'error': 'Missing mobile number'}), 400
        
        TO_NUMBER = f'whatsapp:+91{mobile_number}'

        message = client.messages.create(
            from_=FROM_NUMBER,
            body=message_text,
            to=TO_NUMBER
        )

        return jsonify({'status': 'sent', 'sid': message.sid})

    except Exception as e:
        print(f"❌ Error in sending message: {e}")  # 👈 Optional: log errors too
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
