import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:field_work_2/Students/noteEditorPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';


class StudentNotesPage extends StatefulWidget {
  const StudentNotesPage({super.key});

  @override
  State<StudentNotesPage> createState() => _StudentNotesPageState();
}

class _StudentNotesPageState extends State<StudentNotesPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notes = [];
  bool _isOffline = false;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotes();
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

  Future<void> _fetchNotes() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    final upsertsStr = prefs.getString('pending_notes_upsert');
    final deletesStr = prefs.getString('pending_notes_delete');
    int uCount = upsertsStr != null ? jsonDecode(upsertsStr).length : 0;
    int dCount = deletesStr != null ? jsonDecode(deletesStr).length : 0;
    setState(() {
      _pendingSyncCount = uCount + dCount;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await supabase
            .from('student_notes')
            .select()
            .eq('user_id', userId)
            .order('note_date', ascending: false);

        final List<Map<String, dynamic>> fetchedNotes = List<Map<String, dynamic>>.from(response);
        await prefs.setString('cached_student_notes', jsonEncode(fetchedNotes));

        setState(() {
          _notes = fetchedNotes;
          _isOffline = false;
        });

        if (_pendingSyncCount > 0) {
          _syncOfflineNotes();
        }
      }
    } catch (e) {
      debugPrint("Error fetching notes: $e");
      if (_isNetworkError(e)) {
        final notesStr = prefs.getString('cached_student_notes');
        setState(() {
          if (notesStr != null) {
            _notes = List<Map<String, dynamic>>.from(jsonDecode(notesStr));
          }
          _isOffline = true;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncOfflineNotes() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      final deletesStr = prefs.getString('pending_notes_delete');
      if (deletesStr != null) {
        final List<dynamic> deletes = jsonDecode(deletesStr);
        final List<dynamic> remainingDeletes = [];
        for (var id in deletes) {
          try {
            await supabase.from('student_notes').delete().eq('id', id);
          } catch (e) {
            if (_isNetworkError(e)) {
              remainingDeletes.add(id);
            }
          }
        }
        await prefs.setString('pending_notes_delete', jsonEncode(remainingDeletes));
      }

      final upsertsStr = prefs.getString('pending_notes_upsert');
      if (upsertsStr != null) {
        final List<dynamic> upserts = jsonDecode(upsertsStr);
        final List<dynamic> remainingUpserts = [];
        for (var note in upserts) {
          try {
            final noteMap = Map<String, dynamic>.from(note);
            await supabase.from('student_notes').upsert({
              'id': noteMap['id'],
              'user_id': noteMap['user_id'],
              'title': noteMap['title'],
              'description': noteMap['description'],
              'note_date': noteMap['note_date'],
              'updated_at': noteMap['updated_at'],
            });
          } catch (e) {
            if (_isNetworkError(e)) {
              remainingUpserts.add(note);
            }
          }
        }
        await prefs.setString('pending_notes_upsert', jsonEncode(remainingUpserts));
      }

      final updatedUpserts = prefs.getString('pending_notes_upsert');
      final updatedDeletes = prefs.getString('pending_notes_delete');
      int uCount = updatedUpserts != null ? jsonDecode(updatedUpserts).length : 0;
      int dCount = updatedDeletes != null ? jsonDecode(updatedDeletes).length : 0;

      setState(() {
        _pendingSyncCount = uCount + dCount;
        _isSyncing = false;
        if (_pendingSyncCount == 0) {
          _isOffline = false;
        }
      });

      if (_pendingSyncCount == 0) {
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          final response = await supabase
              .from('student_notes')
              .select()
              .eq('user_id', userId)
              .order('note_date', ascending: false);

          setState(() {
            _notes = List<Map<String, dynamic>>.from(response);
          });
          await prefs.setString('cached_student_notes', jsonEncode(_notes));
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Successfully synchronized offline notes!",
                style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
              ),
              backgroundColor: Colors.teal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error syncing notes: $e");
      setState(() {
        _isSyncing = false;
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "";
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFE65100),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Bad internet or no internet, switching to offline mode",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_pendingSyncCount > 0)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF90CAF9), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_rounded, color: Color(0xFF1E88E5), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "$_pendingSyncCount note(s) waiting to sync.",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E88E5),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1E88E5),
                            ),
                          )
                        : TextButton(
                            onPressed: _syncOfflineNotes,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              backgroundColor: const Color(0xFF1E88E5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              "SYNC NOW",
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Notes Grid
            Expanded(
              child: _notes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.note_alt_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No notes written yet",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Tap the '+' button to write your first note.",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                      itemCount: _notes.length,
                      itemBuilder: (context, index) {
                        final note = _notes[index];
                        final title = note['title'] ?? 'Untitled Note';
                        final desc = note['description'] ?? '';
                        final noteDate = note['note_date'];

                        return Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: Colors.grey[200]!,
                              width: 1.5,
                            ),
                          ),
                          color: Colors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      NoteEditorPage(note: note),
                                ),
                              );
                              if (result == true) {
                                _fetchNotes();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Date badge
                                      Expanded(
                                        child: Text(
                                          _formatDate(noteDate),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // Trash icon
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: Colors.grey[400],
                                        ),
                                        onPressed: () async {
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
                                                    style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: Text(
                                                    "Delete",
                                                    style: GoogleFonts.outfit(color: const Color(0xFF1E88E5), fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            await supabase
                                                .from('student_notes')
                                                .delete()
                                                .eq('id', note['id']);
                                            _fetchNotes();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    title,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (desc.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Expanded(
                                      child: Text(
                                        desc,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          height: 1.3,
                                        ),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NoteEditorPage()),
          );
          if (result == true) {
            _fetchNotes();
          }
        },
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
