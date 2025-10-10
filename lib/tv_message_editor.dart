import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TvMessageEditor extends StatefulWidget {
  const TvMessageEditor({super.key});

  @override
  State<TvMessageEditor> createState() => _TvMessageEditorState();
}

class _TvMessageEditorState extends State<TvMessageEditor> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('tv')
          .doc('marquee')
          .get();
      _controller.text = (doc.data()?['text'] as String?) ?? '';
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('tv')
          .doc('marquee')
          .set({'text': _controller.text.trim()}, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הודעת טלוויזיה נשמרה')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('שמירה נכשלה')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('עריכת הודעת טלוויזיה')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: TextField(
                controller: _controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'הודעה נגללת במסך הטלוויזיה',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'שומר...' : 'שמור'),
            ),
          ],
        ),
      ),
    );
  }
}
