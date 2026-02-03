import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';

class AllSongStoreScreen extends StatefulWidget {
  const AllSongStoreScreen({super.key});

  @override
  State<AllSongStoreScreen> createState() => _AllSongStoreScreenState();
}

class _AllSongStoreScreenState extends State<AllSongStoreScreen> {
  List<Map<String, String>> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsJson = prefs.getString('stored_songs') ?? '[]';
      final List<dynamic> decodedSongs = json.decode(songsJson);

      setState(() {
        _songs = decodedSongs.map((song) => Map<String, String>.from(song)).toList();
        _isLoading = false;
      });

      print('📚 Loaded ${_songs.length} songs from storage');
    } catch (e) {
      print('❌ Error loading songs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSong(int index) async {
    try {
      setState(() {
        _songs.removeAt(index);
      });

      final prefs = await SharedPreferences.getInstance();
      final songsJson = json.encode(_songs);
      await prefs.setString('stored_songs', songsJson);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Song removed'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );

      print('🗑️ Song deleted, ${_songs.length} songs remaining');
    } catch (e) {
      print('❌ Error deleting song: $e');
    }
  }

  void _playSong(Map<String, String> song) {
    // Return the selected song to HomeScreen
    Navigator.pop(context, song);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'All Songs',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_songs.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${_songs.length} Songs',
                    style: TextStyle(
                      color: Colors.cyan,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.cyan,
              ),
            )
          : _songs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 80.sp,
                        color: Colors.grey[700],
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        'No Songs Yet',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        'Upload audio files to see them here',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    final songTitle = song['title'] ?? 'Unknown';
                    final songPath = song['path'] ?? '';

                    return Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        leading: Container(
                          width: 50.w,
                          height: 50.h,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.cyan, Colors.blue],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 28.sp,
                          ),
                        ),
                        title: Text(
                          songTitle,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Song ${index + 1}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12.sp,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.play_circle_filled,
                                color: Colors.cyan,
                                size: 32.sp,
                              ),
                              onPressed: () => _playSong(song),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 24.sp,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      backgroundColor: const Color(0xFF16213E),
                                      title: Text(
                                        'Delete Song?',
                                        style: TextStyle(color: Colors.white, fontSize: 18.sp),
                                      ),
                                      content: Text(
                                        'Are you sure you want to remove "$songTitle"?',
                                        style: TextStyle(color: Colors.grey[300], fontSize: 14.sp),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text(
                                            'Cancel',
                                            style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _deleteSong(index);
                                          },
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red, fontSize: 14.sp),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

