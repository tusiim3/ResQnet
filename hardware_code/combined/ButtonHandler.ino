void checkButton() {
    
    static bool lastButtonState = HIGH;
    int currentButtonState = digitalRead(BUTTON_PIN);
    unsigned long currentTime = millis();

    if (currentButtonState != lastButtonState) {
        if (currentTime - lastClickTime > BUTTON_DEBOUNCE_DELAY) {
            if (currentButtonState == LOW) {
                clickCount++;
                lastClickTime = currentTime;
                Serial.print(F("Button press detected. Clicks: "));
                Serial.println(clickCount);
            }
        }
    }
    lastButtonState = currentButtonState;

    if (clickCount > 0 && (currentTime - lastClickTime > MULTI_PRESS_WINDOW)) {
        if (alertActive) {
            if (clickCount == 2) {
                Serial.println(F("Two presses - sending help request immediately"));

                // Retry sending SMS up to 3 times
                bool alertSent = sendSMSWithRetry(userContact, "user needs help", 3);

                if (alertSent) {
                    Serial.println(F("Immediate alert sent successfully with retries."));
                } else {
                    Serial.println(F("Failed to send immediate alert after retries."));
                }

                waitingForUserResponse = true;
                waitingForCoordinates = true;

                alertActive = false; // Turn off buzzer and LED
                digitalWrite(LED_PIN, LOW);
                digitalWrite(BUZZER_PIN, LOW);

                // Do NOT call resetAlert() here to keep waiting for user response
            } else if (clickCount == 3) {
                Serial.println(F("Three presses - alert cancelled"));
                resetAlert();
            }
        }
        clickCount = 0;
    }
}


void resetAlert() {
  alertActive = false;
  crashDetected = false;
  digitalWrite(LED_PIN, LOW);
  digitalWrite(BUZZER_PIN, LOW);
  Serial.println(F("Alert system reset"));
}
