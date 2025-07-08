#include <SoftwareSerial.h>
#include <Wire.h>
#include <MPU6050.h>
#define MAX_PAIRS 10

MPU6050 mpu;

//change the pin conflicts
SoftwareSerial sim800(3, 2); 

//SIM 800 variables

String contacts[MAX_PAIRS];
String locations[MAX_PAIRS];
String userContact = ""; //string to store user's contact
int pairCount = 0;
bool userContactCaptured = false; //
bool alertSMSsent = false;
//MPU f
// Crash detection thresholds
const float TILT_ANGLE_THRESHOLD = 35.0; // degrees (adjusted for boda boda)
const int ACCEL_CHANGE_THRESHOLD_RAW = 20000; // Raw units for sudden acceleration/deceleration change in any axis (~2.5g)
                                         
const unsigned long INACTIVITY_TIMEOUT = 10000; // 10 seconds
const int BUTTON_PIN = 4;
const int BUZZER_PIN = 5; // Define buzzer pin

// State variables
bool crashDetected = false;
bool alertActive = false;
unsigned long crashTime = 0;

// MPU6050 previous raw readings for change detection
int16_t prevAx = 0, prevAy = 0, prevAz = 0;

// Button multi-press detection
unsigned long lastClickTime = 0;
int clickCount = 0;
const unsigned long BUTTON_DEBOUNCE_DELAY = 50; // milliseconds
const unsigned long MULTI_PRESS_WINDOW = 1000; // 1 second for multi-press window


void setup() {
    Serial.begin(9600);
	
	//SIM800 initialization
    sim800.begin(9600);
    delay(1000);

    sim800.println("AT");
    delay(500);

    sim800.println("AT+CMGF=1"); // Set SMS to Text Mode (text mode)
    delay(500);

    sim800.println("AT+CNMI=1,2,0,0,0"); // Immediate notification of new SMS
    delay(500);

    Serial.println("Setup complete. Waiting for SMS...");
	delay(500);

	//MPU initialization
	Wire.begin();

	pinMode(BUTTON_PIN, INPUT_PULLUP);
	pinMode(LED_BUILTIN, OUTPUT);
	pinMode(BUZZER_PIN, OUTPUT); // Set buzzer pin as output

	// Initialize MPU6050
	mpu.initialize();

	if (mpu.testConnection()) {
	Serial.println("MPU6050 connected successfully");
	} else {
	Serial.println("MPU6050 connection failed");
	while(1); // Halt if MPU6050 not connected
	}

	// Get initial readings for change detection
	mpu.getAcceleration(&prevAx, &prevAy, &prevAz);

	Serial.println("Smart Helmet initialized. Monitoring for crashes...");	
}

void loop() {
	
	if (!userContactCaptured) {captureUserContact();}
	
	checkButton();

	if (!alertActive) {
		checkForCrash();
	} else {
		handleAlertCountdown();
	}

	delay(100); // 10Hz sampling rate
	
	
	//send alert if crash detected
	if (crashDetected && alertActive && !alertSMSsent) {
		String alertSMS = "crash detected send user information";
		sendSMS(userContact, alertSMS);
		alertSMSsent = false;
	}
	
	checkIncomingSMS();
	
	
    if (crashDetected && pairCount > 1) {  // Need at least two contacts
        String firstLocation = locations[0];
        String alertMessage = "The contact at location \"" + firstLocation + "\" might be in trouble.";

        Serial.println("Sending alert message to all contacts except the first...");

        for (int i = 1; i < pairCount; i++) {
            sendSMS(contacts[i], alertMessage);
            delay(10000); // Wait 10 seconds between messages
        }

        pairCount = 0;      // Reset after sending
        crashDetected = false; // Reset crash flag
        Serial.println("All alert messages sent.");
    }
}

// Function to send SMS to a single phone number
void sendSMS(String phoneNumber, String message) {
    Serial.println("Sending SMS to: " + phoneNumber);
    sim800.print("AT+CMGS=\"");
    sim800.print(phoneNumber);
    sim800.println("\"");
    delay(1000);
    sim800.println(message);
    sim800.write(26); // CTRL+Z to send SMS
    delay(5000);      // Wait for message to be sent
    Serial.println("Message sent to " + phoneNumber);
}

// Check for incoming SMS and parse contact-location pairs
void checkIncomingSMS() {
    if (sim800.available()) {
        String line = sim800.readStringUntil('\n');
        line.trim();

        if (line.length() > 0) {
            Serial.println("SIM800: " + line);

            // Look for +CMT: header indicating incoming SMS
            if (line.startsWith("+CMT:")) {
                // Next line is the SMS content
                while (!sim800.available()) {
                    delay(10);
                }
                String smsContent = sim800.readStringUntil('\n');
                smsContent.trim();

                Serial.println("Received SMS content: " + smsContent);

                parseContactLocationPairs(smsContent);

                // Debug print all pairs
                for (int i = 0; i < pairCount; i++) {
                    Serial.println("Contact: " + contacts[i] + " Location: " + locations[i]);
                }
            }
        }
    }
}

// Parse semicolon-separated contact-location pairs from SMS content
void parseContactLocationPairs(String sms) {
    pairCount = 0;

    int start = 0;
    int semicolonIndex = sms.indexOf(';');

    while (semicolonIndex != -1 && pairCount < MAX_PAIRS) {
        String pair = sms.substring(start, semicolonIndex);
        storePair(pair);
        start = semicolonIndex + 1;
        semicolonIndex = sms.indexOf(';', start);
    }

    // Handle last or only pair (no trailing semicolon)
    if (start < sms.length() && pairCount < MAX_PAIRS) {
        String pair = sms.substring(start);
        storePair(pair);
    }
}

// Store a contact-location pair separated by '-'
void storePair(String pair) {
    int dashIndex = pair.indexOf('-');
    if (dashIndex != -1) {
        String contact = pair.substring(0, dashIndex);
        String location = pair.substring(dashIndex + 1);

        contact.trim();
        location.trim();

        contacts[pairCount] = contact;
        locations[pairCount] = location;
        pairCount++;
        } else {
            Serial.println("Invalid pair (missing '-'): " + pair);
    }
}


// send a messege to the users phone to inititate a response of the contact
// parsing the userContact
void  captureUserContact() {
	if (sim800.available()){
		String SmsData = sim800.readString();
		
		int index = SmsData.indexOf("+CMT");
		
		if (index != -1) {
			int firstQuote = SmsData.indexOf("\"", index+5);
			int secondQuote = SmsData.indexOf("\"", firstQuote+1);
			if (firstQuote != -1 && secondQuote != -1 ) {
				String senderNumber = SmsData.substring(firstQuote+1, secondQuote);
				senderNumber.trim();
				
				userContact = senderNumber;
				userContactCaptured = true;
				
				Serial.println("capture user contact: " + userContact);
			} else { Serial.println("failed to parse number:"); }
		}
	}
	
}


void checkForCrash() {
  int16_t ax, ay, az, gx, gy, gz;
  mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);

  // Calculate total acceleration magnitude (still useful for tilt even if not for raw impact)
  // Convert to g-force for tilt calculation, as tilt math relies on 1g being vertical
  float accelX_g = ax / 16384.0;
  float accelY_g = ay / 16384.0;
  float accelZ_g = az / 16384.0;
  float totalAccel_g = sqrt(accelX_g*accelX_g + accelY_g*accelY_g + accelZ_g*accelZ_g);

  // Calculate tilt angle (simplified - angle from vertical)
  float tiltAngle = 0.0;
  if (totalAccel_g > 0.1) { // Avoid division by zero if sensor is saturated or reading zero
     tiltAngle = acos(abs(accelZ_g) / totalAccel_g) * 180.0 / PI;
  }

  // Unified Impact Detection (rapid acceleration/deceleration in any direction)
  int16_t deltaAx = abs(ax - prevAx);
  int16_t deltaAy = abs(ay - prevAy);
  int16_t deltaAz = abs(az - prevAz);

  bool significantImpactDetected = (deltaAx > ACCEL_CHANGE_THRESHOLD_RAW ||
                                    deltaAy > ACCEL_CHANGE_THRESHOLD_RAW ||
                                    deltaAz > ACCEL_CHANGE_THRESHOLD_RAW);

  // Crash condition: Significant impact AND abnormal tilt
  if (significantImpactDetected && tiltAngle > TILT_ANGLE_THRESHOLD) {
    Serial.println("CRASH DETECTED!");
    Serial.print("Accel Changes (RAW): X="); Serial.print(deltaAx);
    Serial.print(", Y="); Serial.print(deltaAy);
    Serial.print(", Z="); Serial.print(deltaAz);
    Serial.print(" | Tilt: "); Serial.print(tiltAngle, 1); Serial.println("°");
    triggerAlert("Combined Impact and Tilt");
    return;
  }

  // Store current values for next iteration
  prevAx = ax;
  prevAy = ay;
  prevAz = az;

  // Debug output every 2 seconds
  static unsigned long lastDebug = 0;
  if (millis() - lastDebug > 2000) {
    Serial.print("Accel XYZ (RAW): ");
    Serial.print(ax); Serial.print(", ");
    Serial.print(ay); Serial.print(", ");
    Serial.print(az); Serial.print(" | ");
    Serial.print("Tilt: "); Serial.print(tiltAngle, 1); Serial.println("°");
    lastDebug = millis();
  }
}

void triggerAlert(String reason) {
  crashDetected = true;
  alertActive = true;
  crashTime = millis();

  Serial.println("=== ALERT TRIGGERED ===");
  Serial.println("Reason: " + reason);
  Serial.println("Starting 10-second countdown...");
  Serial.println("2 presses to send immediate alert, 3 presses to cancel.");

  // Start blinking LED and continuous buzzer
  digitalWrite(LED_BUILTIN, HIGH);
  digitalWrite(BUZZER_PIN, HIGH);
}

void handleAlertCountdown() {
  unsigned long elapsed = millis() - crashTime;
  unsigned long remaining = INACTIVITY_TIMEOUT - elapsed;

  // Blink LED and beep buzzer during countdown
  if ((millis() / 250) % 2) {
    digitalWrite(LED_BUILTIN, HIGH);
    digitalWrite(BUZZER_PIN, HIGH);
  } else {
    digitalWrite(LED_BUILTIN, LOW);
    digitalWrite(BUZZER_PIN, LOW);
  }

  // Print countdown every second
  static unsigned long lastCountdown = 0;
  if (millis() - lastCountdown > 1000) {
    Serial.print("Alert in: ");
    Serial.print(remaining / 1000);
    Serial.println(" seconds");
    lastCountdown = millis();
  }

  // Timeout reached - send emergency alert
  if (elapsed >= INACTIVITY_TIMEOUT) {
    sendEmergencyAlert();
  }
}

void checkButton() {
  static bool lastButtonState = HIGH; // Track previous state for edge detection
  int currentButtonState = digitalRead(BUTTON_PIN);
  unsigned long currentTime = millis();

  // Debounce logic
  if (currentButtonState != lastButtonState) {
    if (currentTime - lastClickTime > BUTTON_DEBOUNCE_DELAY) {
      if (currentButtonState == LOW) { // Button press detected (falling edge)
        clickCount++;
        lastClickTime = currentTime;
        Serial.print("Button press detected. Clicks: "); Serial.println(clickCount);
      }
    }
  }
  lastButtonState = currentButtonState;

  // Check for multi-press window timeout
  if (clickCount > 0 && (currentTime - lastClickTime > MULTI_PRESS_WINDOW)) {
    if (clickCount == 2) {
      Serial.println("Two presses detected - Sending immediate alert!");
      sendEmergencyAlert(); // Immediately send alert
    } else if (clickCount == 3) {
      Serial.println("Three presses detected - Canceling alert!");
      cancelAlert(); // Cancel alert
    } else {
      Serial.print("Unsupported number of presses (");
      Serial.print(clickCount);
      Serial.println(") - Resetting.");
    }
    clickCount = 0; // Reset click count after processing or timeout
  }
}

void sendEmergencyAlert() {
  Serial.println("=== EMERGENCY ALERT SENT ===");
  Serial.println("SMS: 'Rider down. Immediate help needed.'");
  Serial.println("Coordinates: [GPS data would go here]");
  Serial.println("Helmet ID: HELMET_001");

  // Reset state
  alertActive = false;
  crashDetected = false;
  alertSMSsent = false;
  digitalWrite(LED_BUILTIN, LOW);
  digitalWrite(BUZZER_PIN, LOW); // Turn off buzzer

  Serial.println("Alert sent. Resuming normal monitoring...");
}

void cancelAlert() {
  alertActive = false;
  crashDetected = false;
  alertSMSsent = false;
  digitalWrite(LED_BUILTIN, LOW);
  digitalWrite(BUZZER_PIN, LOW); // Turn off buzzer

  Serial.println("Alert canceled. Resuming normal monitoring...");
}

void calibrateSensor() {
  Serial.println("Initial sensor read...");
  Serial.println("Initial readings set.");
} 