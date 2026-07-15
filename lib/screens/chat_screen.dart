import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/mensaje_chat_model.dart';
import '../../config/theme.dart';

class ChatScreen extends StatefulWidget {
  final int idServicio;
  final String conductorNombre;
  final String? conductorFoto;
  final String? conductorTelefono;

  const ChatScreen({
    super.key,
    required this.idServicio,
    required this.conductorNombre,
    this.conductorFoto,
    this.conductorTelefono,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chat = context.read<ChatProvider>();
      chat.cargarMensajes(widget.idServicio);
      chat.startPolling(widget.idServicio);
    });
  }

  @override
  void dispose() {
    context.read<ChatProvider>().stopPolling();
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviarMensaje() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    _messageCtrl.clear();
    _focusNode.requestFocus();
    await context.read<ChatProvider>().enviarMensaje(widget.idServicio, text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        titleTextStyle: const TextStyle(
          color: AppTheme.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.bgLight,
              backgroundImage: widget.conductorFoto != null
                  ? NetworkImage(widget.conductorFoto!)
                  : null,
              child: widget.conductorFoto == null
                  ? const Icon(Icons.person, size: 18, color: AppTheme.textLight)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.conductorNombre,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.conductorTelefono != null)
            IconButton(
              icon: const Icon(Icons.phone, color: AppTheme.primary),
              onPressed: () {
                // TODO: launch phone dialer
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.loading && chat.mensajes.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : chat.mensajes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 64, color: AppTheme.textLight),
                            const SizedBox(height: 16),
                            const Text(
                              'Sin mensajes aun',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppTheme.textMedium,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Envia un mensaje para comunicarte con el conductor',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textLight,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: chat.mensajes.length,
                        itemBuilder: (ctx, i) {
                          final msg = chat.mensajes[i];
                          return _buildMessageBubble(msg);
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageCtrl,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      filled: true,
                      fillColor: AppTheme.bgLight,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _enviarMensaje(),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.send, size: 18, color: Colors.white),
                    onPressed: _enviarMensaje,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MensajeChatModel msg) {
    final isMine = !msg.esDelConductor;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMine
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMine
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.mensaje,
              style: TextStyle(
                fontSize: 15,
                color: isMine ? Colors.white : AppTheme.textDark,
              ),
            ),
            if (msg.fechaCreacion != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(msg.fechaCreacion!),
                style: TextStyle(
                  fontSize: 11,
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppTheme.textLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
