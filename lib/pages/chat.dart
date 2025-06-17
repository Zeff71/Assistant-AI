import 'package:ai_assistance/pages/profile.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  final String? conversationId;
  final bool isNew;

  const ChatPage({super.key, required this.conversationId, this.isNew = false});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  bool showScrollToBottomButton = false;
  bool isLoading = false;
  bool _cancelRequested = false;
  bool isNew = false;

  bool hasUserSentMessage = false;
  String conversationTitle = 'Nouvelle conversation';
  String? currentConversationId;
  int selectedIndex = 1; // par défaut Chat

  List<Map<String, dynamic>> messages = [];
  List<Map<String, dynamic>> conversations = [];
  List<Map<String, dynamic>> displayMessages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadConversations();
    _addWelcomeMessage(); // ➕ ligne ajoutée
    currentConversationId =
        widget.conversationId; // S'il est passé en paramètre
    isNew = widget.isNew;
    _scrollController.addListener(() {
      final isBottom =
          _scrollController.offset >=
          _scrollController.position.maxScrollExtent - 50;

      setState(() {
        showScrollToBottomButton = !isBottom;
      });
    });
  }

  void _addWelcomeMessage() {
    setState(() {
      messages.insert(0, {
        'from': 'bot',
        'text':
            "Bienvenue ! Je suis votre assistant virtuel. Comment puis-je vous aider aujourd'hui ?",
      });
    });
  }

  Future<void> _loadMessages() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('conversations')
            .doc(widget.conversationId)
            .collection('messages')
            .orderBy('timestamp')
            .get();

    setState(() {
      messages =
          snapshot.docs.map((doc) {
            return {'from': doc['from'], 'text': doc['text']};
          }).toList();
      hasUserSentMessage = messages.any((msg) => msg['from'] == 'user');
    });
  }

  Future<void> _loadConversations() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('conversations')
            .get();

    final convList =
        snapshot.docs.map((doc) {
          final data = doc.data();
          final updatedAt = data['updatedAt'];

          return {
            'id': doc.id,
            'title': data['title'] ?? 'Sans titre',
            'updatedAt':
                updatedAt is Timestamp
                    ? updatedAt.toDate()
                    : DateTime.fromMillisecondsSinceEpoch(
                      0,
                    ), // valeur par défaut si null
          };
        }).toList();

    setState(() {
      conversations = convList;

      final currentDoc =
          snapshot.docs
              .where((doc) => doc.id == widget.conversationId)
              .toList();

      if (currentDoc.isNotEmpty) {
        conversationTitle =
            currentDoc.first.data()['title'] ?? 'Nouvelle conversation';
      } else {
        conversationTitle = 'Nouvelle conversation';
      }
    });
  }

  void envoyer() async {
    final userInput = _controller.text.trim();
    if (userInput.isEmpty) return;

    final isFirstMessage = (conversationTitle == 'Nouvelle conversation');

    setState(() {
      messages.add({'from': 'user', 'text': userInput});
      isLoading = true;
      _controller.clear();
      messages.add({'from': 'bot', 'text': ''}); // pré-ajoute une réponse vide
      hasUserSentMessage = true;
      _cancelRequested = false;

      // Met à jour le titre si c'était encore "Nouvelle conversation"
      if (isFirstMessage) {
        conversationTitle =
            userInput.length > 20
                ? '${userInput.substring(0, 20)}...'
                : userInput;
      }
    });

    try {
      String fullResponse = '';

      await for (final chunk in GeminiService.sendMessageStream(userInput)) {
        if (_cancelRequested) {
          // Supprime le message du bot si vide ou partiel
          setState(() {
            if (messages.isNotEmpty && messages.last['from'] == 'bot') {
              messages.removeLast();
            }
            isLoading = false;
          });

          // Affiche un message visuel à l'utilisateur
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Réponse annulée."),
              duration: Duration(seconds: 2),
            ),
          );
          return; // sort proprement de la fonction
        }

        fullResponse += chunk;

        setState(() {
          // remplace le dernier message (bot) par sa nouvelle version
          messages[messages.length - 1] = {'from': 'bot', 'text': fullResponse};
        });
      }

      // Enregistre la réponse complète dans Firestore
      if (!_cancelRequested) {
        final userMessage = {
          'from': 'user',
          'text': userInput,
          'timestamp': FieldValue.serverTimestamp(),
        };

        final botMessage = {
          'from': 'bot',
          'text': fullResponse,
          'timestamp': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('conversations')
            .doc(widget.conversationId)
            .update({
              'title': conversationTitle,
              'lastMessage': userInput,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        // Ajoute le message utilisateur dans Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('conversations')
            .doc(widget.conversationId)
            .collection('messages')
            .add(userMessage);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('conversations')
            .doc(widget.conversationId)
            .collection('messages')
            .add(botMessage);
      }
      setState(() {
        isLoading = false;
      });

      // ➕ Recharge les titres des conversations
      await _loadConversations();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Erreur Geminri Streaming: $e');
    }
  }

  void startNewConversation() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) => ChatPage(
              conversationId: null, // On démarre sans ID
              isNew: true,
            ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> groupConversationsByDate(
    List<Map<String, dynamic>> conversations,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var conv in conversations) {
      final DateTime date = conv['updatedAt'];
      final now = DateTime.now();
      String key;

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        key = 'Aujourd\'hui';
      } else if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day - 1) {
        key = 'Hier';
      } else {
        key = '${date.day}/${date.month}/${date.year}';
      }

      grouped.putIfAbsent(key, () => []).add(conv);
    }

    return grouped;
  }

  void scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      displayMessages.add({'from': 'user', 'text': text});
    });

    _messageController.clear();

    // scroll après ajout
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final hasUserSentMessage = messages.any((msg) => msg['from'] == 'user');
    final displayMessages = [...messages];
    if (!hasUserSentMessage) {
      displayMessages.insert(0, {
        'from': 'bot',
        'text':
            "Bienvenue ! Je suis votre assistant virtuel. Comment puis-je vous aider aujourd'hui ?",
        'welcome': true,
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      drawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.blue[800],
              alignment: Alignment.centerLeft,
              child: const Text(
                'Mes Conversations',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            // 🔁 Ajoute les conversations groupées par date
            ...groupConversationsByDate(conversations).entries.expand((entry) {
              final dateLabel = entry.key;
              final convList = entry.value;

              return [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    dateLabel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...convList.map((conv) {
                  final isSelected = conv['id'] == currentConversationId;

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[700] : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          isSelected
                              ? Border.all(
                                color: Colors.lightBlueAccent,
                                width: 2,
                              )
                              : Border.all(color: Colors.transparent),
                    ),
                    child: ListTile(
                      title: Text(
                        conv['title'],
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder:
                                (_) => ChatPage(conversationId: conv['id']),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ];
            }),
          ],
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AppBar(
                  backgroundColor: Colors.black,
                  title: Text(
                    hasUserSentMessage
                        ? conversationTitle
                        : 'Nouvelle conversation',
                    style: const TextStyle(color: Colors.white),
                  ),
                  leading: Builder(
                    builder:
                        (context) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: startNewConversation,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  /*child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: SizedBox(
                            height: 100,
                            width: 100,
                            child: Image(
                              image: AssetImage('assets/images/robot.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "Bienvenue ! Je suis votre assistant virtuel. Comment puis-je vous aider aujourd'hui ?",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),*/
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility:
                        true, // facultatif : pour toujours voir la scrollbar
                    radius: const Radius.circular(8),
                    thickness: 6,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: displayMessages.length,
                      itemBuilder: (context, index) {
                        final msg = displayMessages[index];
                        final isUser = msg['from'] == 'user';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment:
                                isUser
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                            children: [
                              if (!isUser)
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    31,
                                    30,
                                    30,
                                  ),
                                  child: ClipOval(
                                    child: SizedBox(
                                      height: 50,
                                      width: 50,
                                      child: Image.asset(
                                        'assets/images/logo2.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              if (!isUser) const SizedBox(width: 10),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color:
                                        isUser ? Colors.blue : Colors.grey[850],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: MarkdownBody(
                                    data: msg['text'] ?? '',
                                    styleSheet: MarkdownStyleSheet(
                                      p: const TextStyle(color: Colors.white),
                                      strong: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      a: const TextStyle(
                                        color: Colors.lightBlueAccent,
                                      ),
                                      code: TextStyle(
                                        fontFamily: 'monospace',
                                        backgroundColor: Colors.grey[800],
                                        color: Colors.greenAccent,
                                      ),
                                    ),
                                    onTapLink: (text, href, title) async {
                                      if (href != null) {
                                        await launchUrl(Uri.parse(href));
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
            // ⬇️ Ajoute CE BLOC pour afficher l’indicateur
            if (isLoading)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Envoyer un message...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.grey[900],
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => envoyer(),
                        enabled: !isLoading, // désactive pendant chargement
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Bouton envoyer
                    if (!isLoading)
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.blueAccent),
                        onPressed: envoyer,
                      ),

                    // Bouton annuler (visible uniquement pendant le chargement)
                    if (isLoading)
                      IconButton(
                        icon: const Icon(
                          Icons.stop_circle_outlined,
                          color: Colors.blueAccent,
                        ),
                        onPressed: () {
                          setState(() {
                            _cancelRequested = true;
                            isLoading = false;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            // Bouton flottant de scroll en bas
            if (showScrollToBottomButton)
              Positioned(
                right: 16,
                bottom: 90, // juste au-dessus du champ de texte
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.blue,
                  onPressed: scrollToBottom,
                  child: const Icon(Icons.arrow_downward),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.lightBlueAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: selectedIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
        ],
        onTap: (index) {
          // Gérer la navigation ici
          if (index == selectedIndex)
            return; // Déjà sur la page Chat, ne rien faire
          setState(() {
            selectedIndex = index;
          });
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          ProfilePage(), // Remplacez par votre page profil
                ),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          ChatPage(conversationId: widget.conversationId),
                ),
              );
              break;
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
