import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';


class NoteEditorPage extends StatefulWidget {
  final Map<String, dynamic>? note; // Null if creating a new note

  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final supabase = Supabase.instance.client;

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late DateTime _selectedDate;

  String? _noteId;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  Timer? _autoSaveTimer;
  String _saveStatus = "Saved";

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?['title'] ?? '');
    _descController = TextEditingController(
      text: widget.note?['description'] ?? '',
    );

    final noteDateStr = widget.note?['note_date'];
    if (noteDateStr != null) {
      _selectedDate = DateTime.parse(noteDateStr).toLocal();
    } else {
      _selectedDate = DateTime.now();
    }

    _noteId = widget.note?['id'];

    // Listeners to detect changes
    _titleController.addListener(_onContentChanged);
    _descController.addListener(_onContentChanged);

    // Start auto-save timer (every 3 seconds)
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_hasUnsavedChanges) {
        _saveNote();
      }
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (mounted) {
      setState(() {
        _hasUnsavedChanges = true;
        _saveStatus = "Unsaved changes";
      });
    }
  }

  String _generateUuidV4() {
    final Random random = Random.secure();
    final List<int> values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // set version to 4
    values[8] = (values[8] & 0x3f) | 0x80; // set variant to RFC4122
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  bool _isNetworkError(dynamic error) {
    if (error is SocketException || error is HttpException) return true;
    final errStr = error.toString().toLowerCase();
    return errStr.contains('socketexception') ||
        errStr.contains('network') ||
        errStr.contains('failed to host') ||
        errStr.contains('connection failed') ||
        errStr.contains('timed out') ||
        errStr.contains('timeout') ||
        errStr.contains('http status code 0');
  }

  Future<void> _updateLocalCache(Map<String, dynamic> noteData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesStr = prefs.getString('cached_student_notes');
      final List<dynamic> localNotes = notesStr != null ? jsonDecode(notesStr) : [];
      
      final int idx = localNotes.indexWhere((n) => n['id'] == noteData['id']);
      if (idx != -1) {
        localNotes[idx] = noteData;
      } else {
        localNotes.insert(0, noteData);
      }
      await prefs.setString('cached_student_notes', jsonEncode(localNotes));
    } catch (e) {
      debugPrint("Error updating local notes cache: $e");
    }
  }

  Future<void> _queueNoteUpsert(Map<String, dynamic> noteData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueStr = prefs.getString('pending_notes_upsert');
      final List<dynamic> queue = queueStr != null ? jsonDecode(queueStr) : [];

      final int idx = queue.indexWhere((n) => n['id'] == noteData['id']);
      if (idx != -1) {
        queue[idx] = noteData;
      } else {
        queue.add(noteData);
      }
      await prefs.setString('pending_notes_upsert', jsonEncode(queue));
    } catch (e) {
      debugPrint("Error queuing note upsert: $e");
    }
  }

  Future<void> _deleteLocalCache(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesStr = prefs.getString('cached_student_notes');
      if (notesStr != null) {
        final List<dynamic> localNotes = jsonDecode(notesStr);
        localNotes.removeWhere((n) => n['id'] == id);
        await prefs.setString('cached_student_notes', jsonEncode(localNotes));
      }
    } catch (e) {
      debugPrint("Error deleting note from cache: $e");
    }
  }

  Future<void> _queueNoteDelete(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final upsertsStr = prefs.getString('pending_notes_upsert');
      if (upsertsStr != null) {
        final List<dynamic> upserts = jsonDecode(upsertsStr);
        final int initialLen = upserts.length;
        upserts.removeWhere((n) => n['id'] == id);
        await prefs.setString('pending_notes_upsert', jsonEncode(upserts));
        
        if (upserts.length < initialLen) {
          return;
        }
      }

      final deletesStr = prefs.getString('pending_notes_delete');
      final List<dynamic> deletes = deletesStr != null ? jsonDecode(deletesStr) : [];
      if (!deletes.contains(id)) {
        deletes.add(id);
      }
      await prefs.setString('pending_notes_delete', jsonEncode(deletes));
    } catch (e) {
      debugPrint("Error queuing note delete: $e");
    }
  }

  Future<void> _saveNote() async {
    if (!_hasUnsavedChanges) return;

    final title = _titleController.text.trim();
    final description = _descController.text.trim();

    if (_noteId == null && title.isEmpty && description.isEmpty) {
      return;
    }

    final displayTitle = title.isEmpty ? "Untitled Note" : title;

    if (mounted) {
      setState(() {
        _isSaving = true;
        _saveStatus = "Saving...";
      });
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final data = {
      'user_id': userId,
      'title': displayTitle,
      'description': description,
      'note_date': _selectedDate.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      if (_noteId == null) {
        final tempId = _generateUuidV4();
        data['id'] = tempId;

        final response = await supabase
            .from('student_notes')
            .insert(data)
            .select('id')
            .single();
        _noteId = response['id'];
      } else {
        data['id'] = _noteId!;
        await supabase.from('student_notes').update(data).eq('id', _noteId!);
      }

      await _updateLocalCache(data);

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
          _isSaving = false;
          final now = DateTime.now();
          final minutes = now.minute.toString().padLeft(2, '0');
          final seconds = now.second.toString().padLeft(2, '0');
          _saveStatus = "Saved at ${now.hour}:$minutes:$seconds";
        });
      }
    } catch (e) {
      debugPrint("Save failed: $e");
      if (_isNetworkError(e)) {
        _noteId ??= _generateUuidV4();
        data['id'] = _noteId!;

        await _updateLocalCache(data);
        await _queueNoteUpsert(data);

        if (mounted) {
          setState(() {
            _hasUnsavedChanges = false;
            _isSaving = false;
            _saveStatus = "Saved offline";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _saveStatus = "Save failed";
          });
        }
      }
    }
  }

  Future<void> _deleteNote() async {
    if (_noteId == null) {
      Navigator.pop(context);
      return;
    }

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFF1E88E5),
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              "Delete Note",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete this note?",
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54),
          textAlign: TextAlign.left,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: GoogleFonts.outfit(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Delete",
              style: GoogleFonts.outfit(
                color: const Color(0xFF1E88E5),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        _autoSaveTimer?.cancel();
        _hasUnsavedChanges = false;

        try {
          await supabase.from('student_notes').delete().eq('id', _noteId!);
          await _deleteLocalCache(_noteId!);
        } catch (e) {
          if (_isNetworkError(e)) {
            await _deleteLocalCache(_noteId!);
            await _queueNoteDelete(_noteId!);
          } else {
            rethrow;
          }
        }
        navigator.pop(true);
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Error deleting note: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _hasUnsavedChanges = true;
        _saveStatus = "Unsaved changes";
      });
      // Trigger instant save for date change
      _saveNote();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.note == null ? "New Note" : "Edit Note",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_noteId != null)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
              ),
              onPressed: _deleteNote,
            ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Colors.white),
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (_hasUnsavedChanges) {
                await _saveNote();
              }
              navigator.pop(true);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status bar (Auto save indicator, Date selector)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Save status
                  Row(
                    children: [
                      Icon(
                        _saveStatus.startsWith("Saved")
                            ? Icons.cloud_done_outlined
                            : (_isSaving
                                  ? Icons.sync_rounded
                                  : Icons.edit_note_rounded),
                        size: 16,
                        color: _saveStatus.startsWith("Saved")
                            ? Colors.green
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _saveStatus,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Date picker trigger
                  InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: Colors.teal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Title & Description editing fields
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: "Title",
                        hintStyle: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[350],
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: _descController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: "Start typing your note here...",
                          hintStyle: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.grey[400],
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
