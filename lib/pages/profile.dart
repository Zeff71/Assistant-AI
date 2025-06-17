import 'package:ai_assistance/pages/chat.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  void _getCurrentUser() async {
    setState(() {
      _currentUser = _auth.currentUser;
      _isLoading = true;
    });

    // Récupérer les données utilisateur depuis Firestore
    if (_currentUser != null) {
      await _getUserData();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _getUserData() async {
    try {
      if (_currentUser != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(_currentUser!.uid).get();

        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>?;
          });
        }
      }
    } catch (e) {
      print('Erreur lors de la récupération des données utilisateur: $e');
    }
  }

  // Fonction pour obtenir le nom d'affichage
  String _getDisplayName() {
    // D'abord vérifier si on a un nom dans Firestore
    if (_userData != null &&
        _userData!['nom'] != null &&
        _userData!['nom'].toString().isNotEmpty) {
      return _userData!['nom'];
    }
    // Ensuite vérifier le displayName de Firebase Auth
    else if (_currentUser?.displayName != null &&
        _currentUser!.displayName!.isNotEmpty) {
      return _currentUser!.displayName!;
    }
    // Sinon extraire le nom de l'email
    else if (_currentUser?.email != null) {
      String email = _currentUser!.email!;
      return email.split('@')[0];
    } else {
      return 'Utilisateur';
    }
  }

  // Fonction pour changer l'email
  Future<void> _changeEmail(String newEmail) async {
    try {
      if (_currentUser != null) {
        await _currentUser!.verifyBeforeUpdateEmail(newEmail);
        await _currentUser!.reload();
        _getCurrentUser();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email mis à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fonction pour se déconnecter
  Future<void> _signOut() async {
    // Afficher la boîte de dialogue de confirmation
    bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la déconnexion'),
          content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text(
                'Se déconnecter',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
    // Si l'utilisateur a confirmé, procéder à la déconnexion
    if (shouldSignOut == true) {
      try {
        await _auth.signOut();
        Navigator.of(
          context,
        ).pushReplacementNamed('/login'); // Rediriger vers la page de connexion
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la déconnexion: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Fonction pour supprimer le compte
  // Fonction pour supprimer le compte
  Future<void> _deleteAccount() async {
    try {
      if (_currentUser != null) {
        // Supprimer d'abord le document Firestore
        await _firestore.collection('users').doc(_currentUser!.uid).delete();
        // Puis supprimer le compte Firebase Auth
        await _currentUser!.delete();
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Modal pour changer l'email
  void _showChangeEmailDialog() {
    _emailController.text = _currentUser?.email ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Changer l\'adresse email'),
          content: TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Nouvelle adresse email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_emailController.text.isNotEmpty) {
                  _changeEmail(_emailController.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        );
      },
    );
  }

  // Modal de confirmation pour la suppression
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text(
            'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4285F4), // Bleu Google
              Color(0xFF3367D6),
              Color(0xFF1976D2),
            ],
          ),
        ),
        child: SafeArea(
          child:
              _isLoading // ← ICI EST LA CONDITION
                  ? const Center(
                    // ← SI _isLoading = true, afficher le spinner
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                  : SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            MediaQuery.of(context).size.height -
                            MediaQuery.of(context).padding.top -
                            kBottomNavigationBarHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Titre PROFIL
                            const Text(
                              'PROFIL',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Card du profil
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Column(
                                    children: [
                                      // Avatar
                                      CircleAvatar(
                                        radius: 50,
                                        backgroundColor: Colors.black,
                                        child: ClipOval(
                                          child: SizedBox(
                                            height: 100,
                                            width: 100,
                                            child: Image(
                                              image: AssetImage(
                                                'assets/images/logo2.png',
                                              ),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // Nom d'utilisateur
                                      Text(
                                        _getDisplayName(),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Email
                                      Text(
                                        _currentUser?.email ??
                                            'email@example.com',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.blue[100],
                                        ),
                                      ),
                                      const SizedBox(height: 32),

                                      // Boutons d'action
                                      Column(
                                        children: [
                                          // Bouton Changer l'email
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: _showChangeEmailDialog,
                                              icon: const Icon(
                                                Icons.email,
                                                color: Colors.white,
                                              ),
                                              label: const Text(
                                                'Changer mon adresse Mail',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue
                                                    .withOpacity(0.5),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),

                                          // Bouton Se déconnecter
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: _signOut,
                                              icon: const Icon(
                                                Icons.logout,
                                                color: Colors.white,
                                              ),
                                              label: const Text(
                                                'Se déconnecter',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue
                                                    .withOpacity(0.5),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),

                                          // Bouton Supprimer le compte
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed:
                                                  _showDeleteConfirmationDialog,
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.white,
                                              ),
                                              label: const Text(
                                                'Supprimer le compte',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors
                                                    .pinkAccent
                                                    .withValues(alpha: 0.8),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1976D2),
        selectedItemColor: Colors.grey,
        unselectedItemColor: Colors.white,
        currentIndex: 1,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
        ],
        onTap: (index) {
          // Gérer la navigation ici
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
                  builder: (context) => ChatPage(conversationId: null),
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
    _emailController.dispose();
    super.dispose();
  }
}
