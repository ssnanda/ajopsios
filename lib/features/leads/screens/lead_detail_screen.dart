import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/widgets/customer_picker.dart';
import '../providers/lead_detail_provider.dart';
import '../widgets/lead_status_stepper.dart';
import 'lead_edit_screen.dart';

/// Default outreach message — same wording as AJOps web's "Numbered Menu (Recommended)"
/// template (LeadsClient.tsx OUTREACH_TEMPLATES), so leads get identically-branded copy
/// regardless of which app staff text from.
String _defaultOutreachMessage(String firstName) {
  final name = firstName.trim().isEmpty ? 'there' : firstName.trim();
  return 'Hi $name! 👋 Thanks for reaching out to NC LLC Agents via https://ncllcagents.com/. '
      "Reply with a number and we'll point you the right way:\n\n"
      '1 - Registered Agent Services\n'
      '2 - Start a New LLC\n'
      '3 - Compliance, Filings, or an Existing LLC\n'
      '4 - Something Else / Talk to a Person';
}

/// https://voice.google.com/u/0/messages?a=nc,+1XXXXXXXXXX opens Google Voice's own "new
/// message" compose pre-addressed to the number (app via universal link if installed, else
/// Safari) — mirrors the "calls" variant of this same deep link. Google doesn't expose a URL
/// parameter to prefill the message body itself (checked — none of the documented/observed
/// voice.google.com query params do this), so the practical equivalent of "prepopulated text"
/// is copying a default message to the clipboard first: the compose box opens empty, but
/// pasting it is one tap instead of typing it out.
Future<void> _launchGoogleVoiceText(BuildContext context, String phone, String firstName) async {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return;
  final e164 = digits.length == 10 ? '1$digits' : digits;
  await Clipboard.setData(ClipboardData(text: _defaultOutreachMessage(firstName)));
  final uri = Uri.parse('https://voice.google.com/u/0/messages?a=nc,+$e164');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ok ? 'Message copied — paste it into Google Voice.' : 'Could not open Google Voice.'),
    ),
  );
}

Future<void> _copyPhone(BuildContext context, String phone) async {
  await Clipboard.setData(ClipboardData(text: phone));
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Phone number copied.')));
  }
}

class LeadDetailScreen extends ConsumerStatefulWidget {
  final Lead lead;
  const LeadDetailScreen({super.key, required this.lead});

  @override
  ConsumerState<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends ConsumerState<LeadDetailScreen> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    final err = await action();
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _setStage(LeadDetailNotifier notifier, Lead lead, String stage) async {
    if (stage == 'customer') {
      final result = await pickCustomer(context, allowManualEntry: true);
      if (result == null || !mounted) return;
      await _run(
        () => notifier.setStage(
          'customer',
          stripeCustomerId: result.customer?.stripeCustomerId,
          nonStripeCustomerName: result.manualName,
        ),
      );
      return;
    }

    if (stage == 'future_follow_up') {
      final now = DateTime.now();
      // Prefill with the lead's existing follow-up date when editing one already set — showDatePicker
      // requires initialDate >= firstDate or it throws, so an overdue (past) existing date falls back
      // to today rather than crashing.
      final existing = DateTime.tryParse(lead.leadFollowUpAt);
      final initialDate = existing != null && !existing.isBefore(now) ? existing : now;
      final date = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
        helpText: 'When to follow up?',
      );
      if (date == null || !mounted) return;
      await _run(
        () => notifier.setStage(
          'future_follow_up',
          followUpAt: date.toIso8601String().split('T').first,
        ),
      );
      return;
    }

    await _run(() => notifier.setStage(stage));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leadDetailProvider(widget.lead));
    final notifier = ref.read(leadDetailProvider(widget.lead).notifier);
    final lead = state.lead;

    return Scaffold(
      appBar: AppBar(
        title: Text(lead.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Lead',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => LeadEditScreen(lead: lead)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(lead: lead),
          const SizedBox(height: 16),
          Text(
            'LEAD STATUS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          LeadStatusStepper(
            lead: lead,
            busy: state.busy,
            onChange: (stage) => _setStage(notifier, lead, stage),
          ),
          const SizedBox(height: 20),
          Text(
            'NOTES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          if (lead.notesList.isEmpty)
            Text('No notes yet.', style: TextStyle(color: Colors.grey.shade600))
          else
            ...lead.notesList.map(
              (n) => Card(
                elevation: 0,
                color: Colors.grey.shade50,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.note),
                      const SizedBox(height: 4),
                      Text(
                        '${n.authorName.isNotEmpty ? n.authorName : "Staff"} · ${n.createdAt}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Add a note...',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                // AjTheme's FilledButtonThemeData sets minimumSize: Size.fromHeight(52), and
                // Size.fromHeight sets WIDTH to infinity, not just height (intentional for
                // full-width CTA buttons elsewhere). Left un-overridden here, that infinite-width
                // minimum fights this Row's finite space and the button (plus its Expanded
                // sibling) fails to lay out at all — the whole row silently disappears instead of
                // rendering, which is why this button was reported as not showing up on device.
                style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                onPressed: state.busy
                    ? null
                    : () async {
                        final text = _noteCtrl.text.trim();
                        if (text.isEmpty) return;
                        _noteCtrl.clear();
                        await _run(() => notifier.addNote(text));
                      },
                child: const Text('Add Note'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Lead lead;
  const _InfoCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lead.company.isNotEmpty)
              _Row(icon: Icons.business_rounded, text: lead.company),
            if (lead.email.isNotEmpty)
              _Row(icon: Icons.email_outlined, text: lead.email),
            if (lead.phone.isNotEmpty)
              _PhoneRow(phone: lead.phone, firstName: lead.name.trim().split(RegExp(r'\s+')).first),
            if (lead.source.isNotEmpty)
              _Row(icon: Icons.source_outlined, text: lead.source),
            if (lead.formTitle.isNotEmpty)
              _Row(icon: Icons.description_outlined, text: lead.formTitle),
            if (lead.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(lead.notes, style: TextStyle(color: Colors.grey.shade700)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  final String phone;
  final String firstName;
  const _PhoneRow({required this.phone, required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.phone_outlined, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(phone)),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18),
            tooltip: 'Copy phone number',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _copyPhone(context, phone),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.sms_outlined, size: 18),
            tooltip: 'Text via Google Voice',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _launchGoogleVoiceText(context, phone, firstName),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Row({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
