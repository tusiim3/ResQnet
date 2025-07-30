#include <SoftwareSerial.h>
#include <Wire.h>
#include <MPU6050.h>
#include <math.h>  // For acos, sqrt and abs

#define MAX_PAIRS 10

// Hardware configuration
SoftwareSerial sim800(3, 2);  // RX, TX
MPU6050 mpu;

// Thresholds (keep as original)
const float TILT_ANGLE_THRESHOLD = 30.0; // degrees
const int ACCEL_CHANGE_THRESHOLD_RAW = 200; // Raw units (~2.5g)
const unsigned long INACTIVITY_TIMEOUT = 10000; // 10 seconds

// Pins
const int BUTTON_PIN = 4;
const int BUZZER_PIN = 5;
const int LED_PIN = 13;

// System state variables
String contacts[MAX_PAIRS];
String locations[MAX_PAIRS];
String userContact = "";
String lastCoordinates = "";
int pairCount = 0;

bool userContactCaptured = false;
bool waitingForUserResponse = false;
bool waitingForCoordinates = false;

bool alertInProgress = false;  // True from first alert SMS sent until emergency alerts sent


// Test mode settings
const String testContact = "+256752761159"; // Your testing phone number
bool testingMode = true;

// Crash detection state
bool crashDetected = false;
bool alertActive = false;
unsigned long crashTime = 0;
int16_t prevAy = 0, prevAz = 0;

// Button handling state
unsigned long lastClickTime = 0;
int clickCount = 0;
const unsigned long BUTTON_DEBOUNCE_DELAY = 50;
const unsigned long MULTI_PRESS_WINDOW = 1000;

// Function prototypes (from other tabs)
void initializeSIM800();
bool sendATCommand(String cmd, String expected, unsigned long timeout);
bool sendSMS(String number, String message);
bool sendSMSWithRetry(String number, String message, byte retries);
void captureUserContact();
void checkIncomingSMS();
void processCoordinates(String content);
void processContacts(String content);
void sendEmergencyAlerts();
void logReceivedContacts();

void checkForCrash();
void triggerAlert();
void handleAlertCountdown();

void checkButton();
void resetAlert();

void setup() {
  Serial.begin(9600);

  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);

  sim800.begin(9600);
  initializeSIM800();

  Wire.begin();
  mpu.initialize();
  if (!mpu.testConnection()) {
    Serial.println(F("MPU6050 connection failed"));
    while (1);
  }

  int16_t ax, ay, az;
  mpu.getAcceleration(&ax, &ay, &az);
  prevAy = ay;
  prevAz = az;

  // *** For your testing, hardcoded contacts here ***
  userContact = "+256708078506";  // Replace with your actual test number or rider phone
  userContactCaptured = true;
  testingMode = true;

  Serial.println(F("SIM800 initialized"));
  Serial.println(F("System Ready"));
  Serial.println(F("Send initial message in format: name - phone"));
}

void loop() {
  if (!userContactCaptured) {
    captureUserContact();  // Block here until user contact is set
  } else {
    checkIncomingSMS();
    checkForCrash();
    checkButton();

    if (alertActive) {
      handleAlertCountdown();
    }

    // After receiving coordinate and contacts, send emergency alerts
    if (waitingForUserResponse && lastCoordinates.length() > 0 && pairCount > 0) {
      Serial.println("Received coordinates and contacts - sending alerts");
      sendEmergencyAlerts();
      waitingForUserResponse = false;
    }
  }
  delay(100);
}
