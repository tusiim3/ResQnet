#include <SoftwareSerial.h>
#include <Wire.h>
#include <MPU6050.h>
#define MAX_PAIRS 10

// =============================================
// Hardware Configuration
// =============================================
SoftwareSerial sim800(3, 2);  // RX, TX with 256 byte buffer
MPU6050 mpu;
const int BUTTON_PIN = 4;
const int BUZZER_PIN = 5;

// =============================================
// SIM800 Messaging Module
// =============================================
class MessageHandler {
private:
    String contacts[MAX_PAIRS];
    String locations[MAX_PAIRS];
    String userContact = "";
    String lastCoordinates = "";
    int pairCount = 0;
    bool userContactCaptured = false;
    
public:
    void initialize() {
        sim800.begin(9600);
        delay(1000);
        sim800.println("AT");
        delay(500);
        sim800.println("AT+CMGF=1");
        delay(500);
        sim800.println("AT+CNMI=1,2,0,0,0");
        delay(500);
        Serial.println("SIM800 initialized");
    }

    bool isUserContactCaptured() {
        return userContactCaptured;
    }

    void captureUserContact() {
        if (sim800.available()) {
            String line = sim800.readStringUntil('\n');
            line.trim();
            
            if (line.startsWith("+CMT:")) {
                // Extract sender number
                int quote1 = line.indexOf('"');
                int quote2 = line.indexOf('"', quote1+1);
                String sender = line.substring(quote1+1, quote2);
                
                // Read message content
                while (!sim800.available()) delay(10);
                String content = sim800.readStringUntil('\n');
                content.trim();
                
                // Check format
                int dashPos = content.indexOf('-');
                if (dashPos != -1) {
                    String name = content.substring(0, dashPos);
                    name.trim();
                    String number = content.substring(dashPos+1);
                    number.trim();
                    
                    userContact = sender;
                    userContactCaptured = true;
                    Serial.println("User contact captured: " + userContact);
                    
                    // Send confirmation
                    sendSMS(userContact, "Smart Helmet registered. Emergency alerts will be sent to this number.");
                }
            }
        }
    }

    void checkIncomingMessages() {
        if (sim800.available()) {
            String line = sim800.readStringUntil('\n');
            line.trim();
            
            if (line.startsWith("+CMT:")) {
                // Read full message content (may be multiple lines)
                String fullContent = "";
                while (sim800.available()) {
                    String contentLine = sim800.readStringUntil('\n');
                    contentLine.trim();
                    fullContent += contentLine + "\n";
                }
                fullContent.trim();
                
                // Check if this is a coordinates message
                if (fullContent.startsWith("null - ")) {
                    // Extract coordinates
                    int coordStart = fullContent.indexOf("null - ") + 7;
                    int coordEnd = fullContent.indexOf('\n', coordStart);
                    if (coordEnd == -1) coordEnd = fullContent.length();
                    
                    lastCoordinates = fullContent.substring(coordStart, coordEnd);
                    lastCoordinates.replace(":", "");
                    
                    // Clean coordinates: remove spaces and trim
                    lastCoordinates.replace(" ", "");
                    lastCoordinates.trim();
                    
                    Serial.println("Received coordinates: " + lastCoordinates);
                    
                    // Parse any emergency contacts that might follow
                    if (coordEnd != fullContent.length()) {
                        parseEmergencyContacts(fullContent.substring(coordEnd));
                    }
                } else {
                    // Parse emergency contacts
                    parseEmergencyContacts(fullContent);
                }
            }
        }
    }

    void parseEmergencyContacts(String content) {
        pairCount = 0;
        int lineStart = 0;
        int lineEnd = content.indexOf('\n');
        
        while (lineEnd != -1 && pairCount < MAX_PAIRS) {
            String line = content.substring(lineStart, lineEnd);
            line.trim();
            
            if (line.length() > 0 && !line.startsWith("null - ")) {
                int dashPos = line.indexOf('-');
                if (dashPos != -1) {
                    String name = line.substring(0, dashPos);
                    name.trim();
                    String contact = line.substring(dashPos+1);
                    contact.trim();
                    
                    if (contact.length() > 3 && contact != "911") {
                        contacts[pairCount] = name;
                        locations[pairCount] = contact;
                        pairCount++;
                        Serial.println("Stored contact: " + name + " - " + contact);
                    }
                }
            }
            lineStart = lineEnd + 1;
            lineEnd = content.indexOf('\n', lineStart);
        }
    }

    void sendSMS(String number, String message) {
        Serial.println("Sending to " + number + ": " + message);
        sim800.print("AT+CMGS=\"");
        sim800.print(number);
        sim800.println("\"");
        delay(1000);
        sim800.println(message);
        sim800.write(26);
        delay(5000);
    }

    void sendEmergencyAlert() {
        if (pairCount == 0 || lastCoordinates.length() == 0) return;
        
        String mapsLink = "https://www.google.com/maps?q=" + lastCoordinates;
        
        // First send to user contact
        sendSMS(userContact, "Emergency alert activated! Help is being notified.\nYour location: " + mapsLink);
        
        // Then send to emergency contacts
        for (int i = 0; i < pairCount; i++) {
            String alertMsg = "EMERGENCY: Motorcycle rider needs assistance\n";
            alertMsg += "Reported location: " + mapsLink + "\n";
            alertMsg += "Nearest facility: " + contacts[i];
            
            sendSMS(locations[i], alertMsg);
            delay(10000); // Wait between messages
        }
        
        // Reset after sending
        lastCoordinates = "";
        pairCount = 0;
    }
};

// =============================================
// MPU6050 Crash Detection Module
// =============================================
class CrashDetector {
private:
    const float TILT_ANGLE_THRESHOLD = 35.0;
    const int ACCEL_CHANGE_THRESHOLD_RAW = 20000;
    const unsigned long INACTIVITY_TIMEOUT = 10000; // 10 seconds
    int16_t prevAx = 0, prevAy = 0, prevAz = 0;
    unsigned long crashTime = 0;
    bool crashDetected = false;
    bool alertActive = false;
    
public:
    void initialize() {
        Wire.begin();
        mpu.initialize();
        if (!mpu.testConnection()) {
            Serial.println("MPU6050 connection failed");
            while(1);
        }
        mpu.getAcceleration(&prevAx, &prevAy, &prevAz);
        Serial.println("Crash detector initialized");
    }

    bool checkForCrash() {
        int16_t ax, ay, az;
        mpu.getAcceleration(&ax, &ay, &az);
        
        // Calculate tilt angle
        float accelX_g = ax / 16384.0;
        float accelZ_g = az / 16384.0;
        float tiltAngle = acos(abs(accelZ_g) / sqrt(accelX_g*accelX_g + accelZ_g*accelZ_g)) * 180.0 / PI;
        
        // Check acceleration changes
        int16_t deltaAx = abs(ax - prevAx);
        int16_t deltaAy = abs(ay - prevAy);
        int16_t deltaAz = abs(az - prevAz);
        
        prevAx = ax;
        prevAy = ay;
        prevAz = az;
        
        bool impactDetected = (deltaAx > ACCEL_CHANGE_THRESHOLD_RAW ||
                             deltaAy > ACCEL_CHANGE_THRESHOLD_RAW ||
                             deltaAz > ACCEL_CHANGE_THRESHOLD_RAW);
        
        return (impactDetected && tiltAngle > TILT_ANGLE_THRESHOLD);
    }

    void triggerAlert() {
        crashDetected = true;
        alertActive = true;
        crashTime = millis();
        digitalWrite(BUZZER_PIN, HIGH);
        digitalWrite(LED_BUILTIN, HIGH);
        Serial.println("Crash detected! Alert initiated.");
    }

    bool handleAlertCountdown() {
        if (!alertActive) return false;
        
        unsigned long elapsed = millis() - crashTime;
        
        // Blink LED and buzzer during countdown
        if ((millis() / 250) % 2) {
            digitalWrite(LED_BUILTIN, HIGH);
            digitalWrite(BUZZER_PIN, HIGH);
        } else {
            digitalWrite(LED_BUILTIN, LOW);
            digitalWrite(BUZZER_PIN, LOW);
        }
        
        // Timeout reached
        if (elapsed >= INACTIVITY_TIMEOUT) {
            resetAlert();
            return true;
        }
        return false;
    }

    void resetAlert() {
        alertActive = false;
        crashDetected = false;
        digitalWrite(LED_BUILTIN, LOW);
        digitalWrite(BUZZER_PIN, LOW);
    }

    bool isAlertActive() {
        return alertActive;
    }
};

// =============================================
// Button Handler
// =============================================
class ButtonHandler {
private:
    unsigned long lastClickTime = 0;
    int clickCount = 0;
    const unsigned long BUTTON_DEBOUNCE_DELAY = 50;
    const unsigned long MULTI_PRESS_WINDOW = 1000;
    
public:
    void checkButton(bool alertActive) {
        static bool lastButtonState = HIGH;
        int currentButtonState = digitalRead(BUTTON_PIN);
        unsigned long currentTime = millis();

        // Debounce logic
        if (currentButtonState != lastButtonState) {
            if (currentTime - lastClickTime > BUTTON_DEBOUNCE_DELAY) {
                if (currentButtonState == LOW) { // Button press detected
                    clickCount++;
                    lastClickTime = currentTime;
                    Serial.print("Button press detected. Clicks: "); Serial.println(clickCount);
                }
            }
        }
        lastButtonState = currentButtonState;

        // Check for multi-press window timeout
        if (clickCount > 0 && (currentTime - lastClickTime > MULTI_PRESS_WINDOW)) {
            if (alertActive) {
                if (clickCount == 2) {
                    Serial.println("Two presses - Immediate alert");
                } else if (clickCount == 3) {
                    Serial.println("Three presses - Cancel alert");
                }
            }
            clickCount = 0;
        }
    }
    
    int getClickCount() {
        return clickCount;
    }
    
    void resetClickCount() {
        clickCount = 0;
    }
};

// =============================================
// System Integration
// =============================================
MessageHandler messenger;
CrashDetector detector;
ButtonHandler buttonHandler;

void setup() {
    Serial.begin(9600);
    pinMode(BUTTON_PIN, INPUT_PULLUP);
    pinMode(BUZZER_PIN, OUTPUT);
    pinMode(LED_BUILTIN, OUTPUT);
    
    messenger.initialize();
    detector.initialize();
    
    Serial.println("Smart Helmet System Ready");
}

void loop() {
    if (!messenger.isUserContactCaptured()) {
        messenger.captureUserContact();
    } else {
        messenger.checkIncomingMessages();
        buttonHandler.checkButton(detector.isAlertActive());
        
        if (!detector.isAlertActive() && detector.checkForCrash()) {
            detector.triggerAlert();
            messenger.sendSMS(messenger.getUserContact(), 
                             "CRASH DETECTED! Please respond with your location and emergency contacts.");
        }
        
        if (detector.isAlertActive()) {
            // Handle button presses
            int clicks = buttonHandler.getClickCount();
            if (clicks == 2) {
                messenger.sendEmergencyAlert();
                detector.resetAlert();
                buttonHandler.resetClickCount();
            } else if (clicks == 3) {
                detector.resetAlert();
                buttonHandler.resetClickCount();
            }
            
            // Handle automatic timeout
            if (detector.handleAlertCountdown()) {
                messenger.sendEmergencyAlert();
            }
        }
    }
    delay(100);
}