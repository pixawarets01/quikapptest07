import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/gestures.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'chat_message.dart';
import 'chat_service.dart';
import 'dart:convert';
import 'voice_input_card.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatWidget extends StatefulWidget {
  final InAppWebViewController webViewController;
  final String currentUrl;
  final Function(bool) onVisibilityChanged;

  const ChatWidget({
    super.key,
    required this.webViewController,
    required this.currentUrl,
    required this.onVisibilityChanged,
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  late final ChatService _chatService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isLoading = false;
  bool _isListening = false;
  bool _showVoiceCard = false;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(widget.currentUrl);
    _chatService.chatStream.listen((_) {
      _scrollToBottom();
    });
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $error')));
        },
      );
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
    } catch (e) {
      debugPrint('Speech initialization error: $e');
    }
  }

  Future<void> _startListening() async {
    try {
      if (!_isListening) {
        bool available = await _speech.initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
              // Auto send message when voice input is complete
              if (_messageController.text.isNotEmpty) {
                _handleSend();
              }
            }
          },
          onError: (error) {
            setState(() => _isListening = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $error'),
                backgroundColor: Colors.red,
              ),
            );
          },
        );
        if (available) {
          setState(() {
            _isListening = true;
            _showVoiceCard = true;
          });
          await _speech.listen(
            onResult: (result) {
              setState(() {
                _messageController.text = result.recognizedWords;
              });
            },
            localeId: 'en_US',
            listenMode: stt.ListenMode.confirmation,
          );
        }
      } else {
        setState(() {
          _isListening = false;
          _showVoiceCard = false;
        });
        _speech.stop();
      }
    } catch (e) {
      setState(() {
        _isListening = false;
        _showVoiceCard = false;
      });
      debugPrint('Speech recognition error: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatService.dispose();
    _speech.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _handleSend() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    _messageController.clear();
    setState(() => _isLoading = true);

    try {
      await _chatService.processUserMessage(message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleUrl(String url) async {
    if (url.startsWith('tel:') ||
        url.startsWith('mailto:') ||
        url.startsWith('whatsapp:') ||
        url.startsWith('sms:')) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw 'Could not launch $url';
      }
    } else {
      widget.webViewController.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF667eea), // QuikApp primary gradient color
                Color(0xFF764ba2), // QuikApp secondary gradient color
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeader(),
              Expanded(child: _buildChatList()),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'QuikApp Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              widget.onVisibilityChanged(false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return Container(
      color: Colors.white,
      child: StreamBuilder<List<ChatMessage>>(
        stream: _chatService.chatStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
              ),
            );
          }

          final messages = snapshot.data!;
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildMessageBubble(message),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Voice Input Button
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _isListening
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFff4b4b), // Red gradient for active state
                            Color(0xFFff6b6b),
                          ],
                        )
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF667eea),
                            Color(0xFF764ba2),
                          ],
                        ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _startListening,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                            size: 20,
                          ),
                          if (_isListening)
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                                backgroundColor: Colors.white.withOpacity(0.3),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Text Input Field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF667eea).withOpacity(0.2),
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'Listening...'
                          : 'Type your message...',
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2D3748),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
              ),

              // Send Button (only visible when text is typed manually)
              if (!_isListening && _messageController.text.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF667eea),
                        Color(0xFF764ba2),
                      ],
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _handleSend,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFF667eea) : Colors.grey[100],
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _buildMessageContent(
                message, isUser ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message, Color textColor) {
    final messageLines = message.text.split('\n');
    final linkPattern = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: messageLines.map((line) {
        // Check if line contains a link
        final match = linkPattern.firstMatch(line);
        if (match != null) {
          // Extract link title and URL
          final title = match.group(1)!;
          final url = match.group(2)!;

          // If it's a numbered list item with a link
          final numberMatch = RegExp(r'^\d+\.\s*').firstMatch(line);
          if (numberMatch != null) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    numberMatch.group(0)!,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  Expanded(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () => _handleUrl(url),
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF4fd1c5),
                            fontSize: 14,
                            height: 1.5,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Regular link without number
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _handleUrl(url),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF4fd1c5),
                    fontSize: 14,
                    height: 1.5,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          );
        }

        // Regular text line
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            line,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        );
      }).toList(),
    );
  }
}
