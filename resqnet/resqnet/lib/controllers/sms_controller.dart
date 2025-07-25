import 'package:telephony/telephony.dart';
import '../services/sms_service.dart';

class SmsController {
  final Telephony telephony = Telephony.instance;

  // Handle a manually triggered incoming SMS
  Future<void> handleIncomingSms(SmsMessage message) async {
    final sender = message.address ?? "";
    final body = message.body ?? "";

    // Ensure trusted contact is loaded
    String? trustedHardwareContact = SmsService.hardwareContact;

    print("📨 Manual SMS check - From: $sender, Body: $body");
    print("🔐 Trusted hardware contact: $trustedHardwareContact");

    if (trustedHardwareContact != null && sender == trustedHardwareContact) {
      doCustomTask(body);

      final success = await SmsService.sendSms(sender, "✅ Task completed successfully!");
      if (!success) {
        print("⚠️ Failed to send confirmation SMS.");
      }
    } else {
      print("🚫 Unauthorized SMS access attempt from: $sender");
    }
  }

  void doCustomTask(String body) {
    print("🛠️ Performing custom task based on message: '$body'");
    // Your custom logic here (e.g., command parsing)
  }
}
