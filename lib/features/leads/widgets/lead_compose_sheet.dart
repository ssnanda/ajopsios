import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/api/ajops_api.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/utils/error_utils.dart';

/// Email or text a lead: pick an AJMCP assistant, let it draft, edit, then Send.
/// Calls the AJOps web routes (the same ones the web Leads page uses); nothing is sent without the Send tap.
/// Text goes out from the AJPhone line (980) 325-2929; email goes through AJCore's SMTP (ZeptoMail).
Future<bool> showLeadComposeSheet(BuildContext context, Lead lead, {required bool email}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ComposeSheet(lead: lead, email: email),
    ),
  );
  return sent == true;
}

class _ComposeSheet extends StatefulWidget {
  final Lead lead;
  final bool email;
  const _ComposeSheet({required this.lead, required this.email});

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  static const _textMax = 320;
  final _instruction = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  List<String> _assistants = [];
  String? _assistant;
  bool _drafting = false;
  bool _sending = false;
  bool _drafted = false;
  double _elapsed = 0;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAssistants();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _instruction.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadAssistants() async {
    try {
      final resp = await AjopsApi.instance.get('/api/leads/draft');
      final list = ((resp.data as Map)['assistants'] as List? ?? const []).map((e) => e.toString()).toList();
      if (!mounted) return;
      setState(() {
        _assistants = list;
        _assistant = list.isNotEmpty ? list.first : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _draft() async {
    final started = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(started).inMilliseconds / 1000);
    });
    setState(() {
      _drafting = true;
      _error = null;
      _elapsed = 0;
    });
    try {
      final resp = await AjopsApi.instance.post('/api/leads/draft', {
        'leadId': widget.lead.id,
        'channel': widget.email ? 'email' : 'text',
        'assistant': _assistant,
        'instruction': _instruction.text.trim(),
      });
      final data = resp.data as Map;
      if (!mounted) return;
      setState(() {
        _subject.text = (data['subject'] ?? '').toString();
        _body.text = (data['body'] ?? '').toString();
        _drafted = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      _timer?.cancel();
      if (mounted) setState(() => _drafting = false);
    }
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await AjopsApi.instance.post(
        widget.email ? '/api/leads/send-email' : '/api/leads/send-text',
        widget.email
            ? {'id': widget.lead.id, 'subject': _subject.text.trim(), 'body': _body.text.trim()}
            : {'id': widget.lead.id, 'body': _body.text.trim()},
      );
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;
    final target = email ? widget.lead.email : widget.lead.phone;
    final over = !email && _body.text.length > _textMax;
    final canSend = !_sending && !_drafting && _body.text.trim().isNotEmpty && (!email || _subject.text.trim().isNotEmpty) && target.isNotEmpty && !over;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${email ? 'Email' : 'Text'} — ${widget.lead.displayName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(email ? 'To $target' : 'To $target · from (980) 325-2929', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _assistant,
                isDense: true,
                decoration: const InputDecoration(labelText: 'Assistant', border: OutlineInputBorder()),
                items: [for (final a in _assistants) DropdownMenuItem(value: a, child: Text(a))],
                onChanged: (v) => setState(() => _assistant = v),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _instruction,
            decoration: const InputDecoration(labelText: 'Optional instruction', hintText: 'e.g. mention the \$98 plan', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: (_assistant == null || _drafting) ? null : _draft,
              child: Text(_drafting ? 'Drafting… ${_elapsed.toStringAsFixed(1)}s' : (_drafted ? 'Regenerate' : 'Draft with AI')),
            ),
          ),
          const SizedBox(height: 12),
          if (email) ...[
            TextField(
              controller: _subject,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _body,
            onChanged: (_) => setState(() {}),
            minLines: email ? 8 : 4,
            maxLines: 14,
            decoration: InputDecoration(
              labelText: email ? 'Message' : 'Text message',
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
              counterText: email ? null : '${_body.text.length}/$_textMax',
              counterStyle: TextStyle(color: over ? Colors.red : null),
            ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 12),
          Row(children: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            const Spacer(),
            FilledButton(onPressed: canSend ? _send : null, child: Text(_sending ? 'Sending…' : (email ? 'Send email' : 'Send text'))),
          ]),
        ],
      ),
    );
  }
}
