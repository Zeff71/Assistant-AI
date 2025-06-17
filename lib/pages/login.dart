import 'package:ai_assistance/pages/chat.dart';
import 'package:ai_assistance/pages/signup.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _obscureText = true; // À placer dans ta classe _State

  void _signIn() async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // Vérifier si l'email est vérifié
      if (!userCredential.user!.emailVerified) {
        // Afficher une boîte de dialogue avec option de renvoyer l'email
        _showEmailVerificationDialog(userCredential.user!);
        await _auth.signOut(); // Déconnecter l'utilisateur
        return;
      }

      final uid = userCredential.user!.uid;
      final convoId = const Uuid().v4();
      final conversationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('conversations')
          .doc(convoId);

      await conversationRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'conversationId': convoId,
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(conversationId: convoId),
        ),
      );
    } catch (e) {
      String errorMessage = "Erreur de connexion";

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMessage = "Aucun utilisateur trouvé avec cet email.";
            break;
          case 'wrong-password':
            errorMessage = "Mot de passe incorrect.";
            break;
          case 'invalid-email':
            errorMessage = "Format d'email invalide.";
            break;
          case 'user-disabled':
            errorMessage = "Ce compte a été désactivé.";
            break;
          default:
            errorMessage = "Erreur : ${e.message}";
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  void _showResendVerificationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController emailController = TextEditingController();
        final TextEditingController passwordController =
            TextEditingController();

        return AlertDialog(
          title: const Text("Renvoyer email de vérification"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Entrez vos identifiants pour renvoyer l'email :"),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Mot de passe",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final UserCredential userCredential = await _auth
                      .signInWithEmailAndPassword(
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                      );

                  if (!userCredential.user!.emailVerified) {
                    await userCredential.user!.sendEmailVerification();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Email de vérification envoyé ! Vérifiez vos spams.",
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  } else {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Votre email est déjà vérifié !"),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }

                  await _auth.signOut();
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erreur : ${e.toString()}"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("Envoyer"),
            ),
          ],
        );
      },
    );
  }

  void _showEmailVerificationDialog(User user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Email non vérifié"),
          content: const Text(
            "Votre email n'est pas encore vérifié. Vérifiez votre boîte de réception (et vos spams) ou renvoyez l'email de vérification.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await user.sendEmailVerification();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Email de vérification envoyé !"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erreur : ${e.toString()}"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("Renvoyer l'email"),
            ),
          ],
        );
      },
    );
  }

  void _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Veuillez saisir votre email pour réinitialiser le mot de passe.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Email de réinitialisation envoyé ! Vérifiez votre boîte de réception.",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      String errorMessage = "Erreur lors de l'envoi de l'email";

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMessage = "Aucun utilisateur trouvé avec cet email.";
            break;
          case 'invalid-email':
            errorMessage = "Format d'email invalide.";
            break;
          default:
            errorMessage = "Erreur : ${e.message}";
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF007FFF), Color(0xFF00BFFF), Color(0xFF87CEFA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'SE CONNECTER',
                  style: TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.black,
                  child: ClipOval(
                    child: SizedBox(
                      height: 100,
                      width: 100,
                      child: Image(
                        image: AssetImage('assets/images/logo2.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  " SAE Assistant ",
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 30),
                _buildTextField(
                  controller: _emailController,
                  hint: 'Email',
                  icon: Icons.person,
                  obscure: false,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _passwordController,
                  hint: 'Mot de passe',
                  icon: Icons.lock,
                  obscure: true,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 80,
                      vertical: 15,
                    ),
                  ),
                  onPressed: _signIn,
                  child: const Text(
                    'Se connecter',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _resetPassword,
                  child: const Text(
                    'Mot de passe oublié ?',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: _showResendVerificationDialog,
                  child: const Text(
                    'Renvoyer email de vérification',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignupPage(),
                      ),
                    );
                  },
                  child: const Text(
                    "S’inscrire",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.lightBlue.shade100.withOpacity(0.3),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure ? _obscureText : false,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white),
          prefixIcon: Icon(icon, color: Colors.white),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          suffixIcon:
              obscure
                  ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                  : null,
        ),
      ),
    );
  }
}
