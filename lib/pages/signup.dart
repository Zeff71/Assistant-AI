import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'login.dart';
import 'politique_de_confidentialite.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String _errorMessage = '';
  bool isPrivacyAccepted = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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
                  'S’INSCRIRE',
                  style: TextStyle(
                    fontSize: 30,
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

                const SizedBox(height: 30),
                _buildTextField(
                  hint: 'Nom',
                  icon: Icons.person,
                  controller: _nameController,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  hint: 'Email',
                  icon: Icons.email_outlined,
                  controller: _emailController,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  hint: 'Mot de passe',
                  icon: Icons.lock,
                  controller: _passwordController,
                  obscure: _obscurePassword,
                  onToggleObscure: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),

                const SizedBox(height: 15),
                _buildTextField(
                  hint: 'Confirmer le mot de passe',
                  icon: Icons.lock,
                  controller: _confirmPasswordController,
                  obscure: _obscureConfirmPassword,
                  onToggleObscure: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),

                const SizedBox(height: 25),
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent, // Rose/Rouge
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 80,
                      vertical: 15,
                    ),
                  ),
                  onPressed: _registerUser,
                  child: const Text(
                    'S’inscrire',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 90),
                CheckboxListTile(
                  value: isPrivacyAccepted,
                  onChanged: (bool? value) {
                    setState(() {
                      isPrivacyAccepted = value ?? false;
                    });
                  },
                  title: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                      children: [
                        const TextSpan(text: "J'ai lu et accepte la "),
                        TextSpan(
                          text: "politique de confidentialité",
                          style: const TextStyle(
                            color: Colors.black,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer:
                              TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              PolitiqueConfidentialitePage(),
                                    ),
                                  );
                                },
                        ),
                      ],
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Déjà un compte ? ",
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      },
                      child: const Text(
                        "Se connecter",
                        style: TextStyle(
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.lightBlue.shade100.withOpacity(0.3),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white),
          prefixIcon: Icon(icon, color: Colors.white),
          suffixIcon:
              onToggleObscure != null
                  ? IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                      color: Colors.black,
                    ),
                    onPressed: onToggleObscure,
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Future<void> _registerUser() async {
    final nom = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = "Les mots de passe ne correspondent pas.";
      });
      return;
    }

    if (!isPrivacyAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Vous devez accepter la politique de confidentialité"),
        ),
      );
      return; // Empêche l’envoi du formulaire
    }

    try {
      // Création de l'utilisateur dans Firebase Auth
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      if (user != null) {
        // Enregistrement dans Firestore
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'uid': user.uid,
                'email': user.email,
                'nom': nom,
                'createdAt': FieldValue.serverTimestamp(),
              });
          print('✅ Données enregistrées dans Firestore');
        } catch (e) {
          print('❌ Erreur lors de l\'enregistrement Firestore : $e');
        }
      }

      // Redirection vers la page de connexion si tout est OK
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use') {
          _errorMessage = "Un compte existe déjà avec cet email.";
        } else if (e.code == 'invalid-email') {
          _errorMessage = "Email invalide.";
        } else if (e.code == 'weak-password') {
          _errorMessage = "Mot de passe trop faible.";
        } else {
          _errorMessage = "Erreur : $e";
        }
      });
    }
  }
}
