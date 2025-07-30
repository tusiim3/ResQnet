void checkForCrash() {
  int16_t ay, az;
  mpu.getAcceleration(nullptr, &ay, &az);

  float accelY_g = ay / 16384.0f;
  float accelZ_g = az / 16384.0f;
  float totalAccel_g = sqrt(accelY_g * accelY_g + accelZ_g * accelZ_g);

  float tiltAngle = 0.0f;
  if (totalAccel_g > 0.1f) {
    tiltAngle = acos(fabs(accelZ_g) / totalAccel_g) * 180.0f / PI;
  }

  int16_t deltaAy = abs(ay - prevAy);
  int16_t deltaAz = abs(az - prevAz);

  bool significantImpactDetected = (deltaAy > ACCEL_CHANGE_THRESHOLD_RAW || deltaAz > ACCEL_CHANGE_THRESHOLD_RAW);

  if (significantImpactDetected && tiltAngle > TILT_ANGLE_THRESHOLD && !alertActive) {
    Serial.println(F("CRASH DETECTED!"));
    Serial.print(F("Accel Changes (RAW): Y=")); Serial.print(deltaAy);
    Serial.print(F(", Z=")); Serial.print(deltaAz);
    Serial.print(F(" | Tilt: ")); Serial.print(tiltAngle, 1); Serial.println(F("°"));
    triggerAlert();
  }

  prevAy = ay;
  prevAz = az;

  static unsigned long lastDebug = 0;
  if (millis() - lastDebug > 2000) {
    Serial.print(F("Accel YZ (RAW): "));
    Serial.print(ay); Serial.print(F(", "));
    Serial.print(az); Serial.print(F(" | "));
    Serial.print(F("Tilt: ")); Serial.print(tiltAngle, 1); Serial.println(F("°"));
    lastDebug = millis();
  }
}

void triggerAlert() {
  crashDetected = true;
  alertActive = true;
  crashTime = millis();
  digitalWrite(LED_PIN, HIGH);
  digitalWrite(BUZZER_PIN, HIGH);
  Serial.println(F("=== ALERT TRIGGERED ==="));
  Serial.println(F("Starting 10-second countdown..."));
  Serial.println(F("2 presses to send immediate alert, 3 presses to cancel."));
}

void handleAlertCountdown() {
    unsigned long elapsed = millis() - crashTime;

    // Flash LED and buzzer every 250 ms
    if ((millis() / 250) % 2) {
        digitalWrite(LED_PIN, HIGH);
        digitalWrite(BUZZER_PIN, HIGH);
    } else {
        digitalWrite(LED_PIN, LOW);
        digitalWrite(BUZZER_PIN, LOW);
    }

    static unsigned long lastCountdown = 0;
    if (millis() - lastCountdown > 1000) {
        Serial.print(F("Alert in: "));
        Serial.print((INACTIVITY_TIMEOUT - elapsed) / 1000);
        Serial.println(F(" seconds"));
        lastCountdown = millis();
    }

    if (elapsed >= INACTIVITY_TIMEOUT || (clickCount == 2 && alertActive)) {
        Serial.println("Sending help request to user");

        // Send "user needs help" SMS to userContact with 3 retries
        bool alertSent = sendSMSWithRetry(userContact, "user needs help", 3);
        if (alertSent) {
            Serial.println(F("Initial alert sent successfully with retries."));
        } else {
            Serial.println(F("Failed to send initial alert after retries."));
        }

        // Fixed coordinates as requested
        const String fixedCoordinates = "0.332232,32.570349";

        // Send location alert to testContact with fixed coordinates regardless of userContact SMS success
        String mapsLink = "https://www.google.com/maps?q=" + fixedCoordinates;
        String alertMsg = "TEST ALERT: Rider needs assistance\nLocation: " + mapsLink;
        Serial.print(F("Sending alert to test contact with fixed coordinates: "));
        Serial.println(testContact);
        sendSMSWithRetry(testContact, alertMsg, 3);

        // Set flags to wait for user's response
        waitingForUserResponse = true;
        waitingForCoordinates = true;

        // Turn off alert signals but keep system waiting for reply
        digitalWrite(LED_PIN, LOW);
        digitalWrite(BUZZER_PIN, LOW);

        // Do NOT reset alert here to keep waiting for incoming coordinates and contacts
    }
}

