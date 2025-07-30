void initializeSIM800() {
  sendATCommand("AT", "OK", 2000);
  sendATCommand("AT+CMGF=1", "OK", 1000);
  sendATCommand("AT+CNMI=1,2,0,0,0", "OK", 1000);
  Serial.println(F("SIM800 initialized"));
}

bool sendATCommand(String cmd, String expected, unsigned long timeout) {
  Serial.print(F("AT CMD: "));
  Serial.println(cmd);
  sim800.println(cmd);
  unsigned long start = millis();
  String response;

  while (millis() - start < timeout) {
    if (sim800.available()) {
      char c = sim800.read();
      response += c;
      if (response.indexOf(expected) != -1) {
        Serial.print(F("Response: "));
        Serial.println(response);
        return true;
      }
    }
  }
  Serial.print(F("AT Command Failed: "));
  Serial.println(cmd);
  Serial.print(F("Response: "));
  Serial.println(response);
  return false;
}

bool sendSMS(String number, String message) {
  Serial.print(F("Sending to "));
  Serial.print(number);
  Serial.print(F(": "));
  Serial.println(message);

  sim800.print("AT+CMGS=\"");
  sim800.print(number);
  sim800.println("\"");
  delay(1000);

  sim800.print(message);
  sim800.write(26); // Ctrl+Z to send

  unsigned long start = millis();
  while (millis() - start < 5000) {
    if (sim800.available()) {
      String response = sim800.readString();
      if (response.indexOf("OK") != -1) {
        Serial.println(F("SMS sent successfully"));
        return true;
      }
    }
  }

  Serial.println(F("SMS send failed"));
  return false;
}

bool sendSMSWithRetry(String number, String message, byte retries) {
  for (byte i = 0; i < retries; i++) {
    Serial.print(F("Attempt "));
    Serial.print(i + 1);
    Serial.print(F(" of "));
    Serial.print(retries);
    Serial.println(F(" to send SMS"));

    if (sendSMS(number, message)) {
      return true;
    }
    delay(2000);
  }
  return false;
}

void captureUserContact() {
  if (sim800.available()) {
    String line = sim800.readStringUntil('\n');
    line.trim();

    if (line.startsWith("+CMT:")) {
      int quote1 = line.indexOf('"');
      int quote2 = line.indexOf('"', quote1 + 1);
      String sender = line.substring(quote1 + 1, quote2);

      while (!sim800.available()) delay(10);  // wait for SMS body
      String content = sim800.readStringUntil('\n');
      content.trim();

      int dashPos = content.indexOf('-');
      if (dashPos != -1) {
        userContact = sender;
        userContactCaptured = true;
        Serial.print(F("User contact captured: "));
        Serial.println(userContact);
      }
    }
  }
}

void checkIncomingSMS() {
  if (sim800.available()) {
    String line = sim800.readStringUntil('\n');
    line.trim();

    if (line.startsWith("+CMT:")) {
      String fullContent = "";
      while (sim800.available()) {
        String contentLine = sim800.readStringUntil('\n');
        contentLine.trim();
        fullContent += contentLine + "\n";
      }
      fullContent.trim();

      Serial.print(F("Received SMS: "));
      Serial.println(fullContent);

      if (waitingForCoordinates && fullContent.startsWith("null - ")) {
        processCoordinates(fullContent);
      } else {
        processContacts(fullContent);
      }
    }
  }
}
  
void processCoordinates(String content) {
  if (!waitingForCoordinates) return;

  int coordStart = content.indexOf("null - ") + 7;
  int coordEnd = content.indexOf('\n', coordStart);
  if (coordEnd == -1) coordEnd = content.length();

  lastCoordinates = content.substring(coordStart, coordEnd);
  lastCoordinates.replace(":", "");
  lastCoordinates.replace(" ", "");
  lastCoordinates.trim();

  Serial.print(F("Processed coordinates: "));
  Serial.println(lastCoordinates);

  waitingForCoordinates = false;

  if (coordEnd != content.length()) {
    processContacts(content.substring(coordEnd));
  }
}

void processContacts(String content) {
  int newPairs = 0;
  int lineStart = 0;
  int lineEnd = content.indexOf('\n');

  while (lineEnd != -1 && (pairCount + newPairs) < MAX_PAIRS) {
    String line = content.substring(lineStart, lineEnd);
    line.trim();

    if (line.length() > 0 && !line.startsWith("null - ")) {
      int dashPos = line.indexOf('-');
      if (dashPos != -1) {
        String name = line.substring(0, dashPos);
        name.trim();
        String number = line.substring(dashPos + 1);
        number.trim();

        if (number.length() > 3) {
          contacts[pairCount + newPairs] = name;
          locations[pairCount + newPairs] = number;
          newPairs++;
          Serial.print(F("Stored contact: "));
          Serial.print(name);
          Serial.print(F(" - "));
          Serial.println(number);
        }
      }
    }

    lineStart = lineEnd + 1;
    lineEnd = content.indexOf('\n', lineStart);
  }
  
  pairCount += newPairs;
  if (newPairs > 0) {
    Serial.print(F("Total contacts stored: "));
    Serial.println(pairCount);
    logReceivedContacts();
  }
}

void logReceivedContacts() {
  Serial.println(F("All received contacts:"));
  for (int i = 0; i < pairCount; i++) {
    Serial.print(i + 1);
    Serial.print(F(". "));
    Serial.print(contacts[i]);
    Serial.print(F(" - "));
    Serial.println(locations[i]);
  }
}

void sendEmergencyAlerts() {
    if (lastCoordinates.length() == 0) {
        Serial.println(F("Cannot send alerts - no coordinates received"));
        return;
    }

    String mapsLink = "https://www.google.com/maps?q=" + lastCoordinates;
    Serial.print(F("Preparing alerts with location: "));
    Serial.println(mapsLink);

    if (testingMode) {
        Serial.println(F("=== TEST MODE ACTIVATED ==="));
        Serial.println(F("Would normally send to these contacts:"));
        logReceivedContacts();

        String alertMsg = "TEST ALERT: Rider needs assistance\nLocation: " + mapsLink;

        Serial.print(F("Actually sending to test contact: "));
        Serial.println(testContact);

        if (sendSMSWithRetry(testContact, alertMsg, 5)) {
            Serial.println(F("Test alert successfully sent"));
        } else {
            Serial.println(F("Failed to send test alert"));
        }
    } else {
        Serial.println(F("PRODUCTION MODE: Sending real alerts"));
        for (int i = 0; i < pairCount; i++) {
            String alertMsg = "EMERGENCY: Rider needs assistance\nLocation: " + mapsLink;

            Serial.print(F("Sending to "));
            Serial.print(locations[i]);
            Serial.print(F(": "));
            Serial.println(alertMsg);

            if (!sendSMSWithRetry(locations[i], alertMsg, 5)) {
                Serial.println(F("Failed to send to this contact"));
            }
            delay(10000);  // To avoid spamming network
        }
        Serial.println(F("All alerts sent to real contacts"));
    }

    
    // Clear coordinates and contacts after sending alerts
    lastCoordinates = "";
    pairCount = 0;

    // Clear waiting flag here, as alert fully completed
    waitingForUserResponse = false;
}
