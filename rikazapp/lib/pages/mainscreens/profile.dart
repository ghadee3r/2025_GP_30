import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// Get the Supabase client instance
final supabase = sb.Supabase.instance.client;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isDarkMode = false;
  String userName = 'Loading...';
  String userEmail = '';

  List<Map<String, dynamic>> presets = [
    {'id': '1', 'name': 'Deep Work', 'sensitivity': 'High', 'triggers': 3},
    {'id': '2', 'name': 'Morning Focus', 'sensitivity': 'Low', 'triggers': 1},
    {'id': '3', 'name': 'Study Session', 'sensitivity': 'Mid', 'triggers': 4},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // --- Profile Data Fetching (Displays Name/Email) ---
  Future<void> _loadUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      // The full name is stored in user_metadata during signup
      final metadata = user.userMetadata;
      
      setState(() {
        userEmail = user.email ?? 'No Email';
        // Use the 'full_name' saved in signup, falling back to email if metadata is null
        userName = metadata?['full_name'] ?? user.email?.split('@')[0] ?? 'User Name';
      });
    }
  }

  void handleDeletePreset(String id) {
    // Existing preset deletion logic (currently mock data)
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Preset'),
        content: const Text('Are you sure you want to delete this preset?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => presets.removeWhere((p) => p['id'] == id));
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- Secure Logout Logic ---
  void handleSignOut() async {
    // 1. Destroy the Supabase session token
    await supabase.auth.signOut();

    // 2. Clear navigation stack and redirect to the login screen
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  void addPreset() {
    // Placeholder for navigation to add preset screen
    Navigator.pushNamed(context, '/add-preset');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              // Profile Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey, width: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        const CircleAvatar(
                          radius: 50,
                          backgroundImage: NetworkImage('https://via.placeholder.com/100'),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(5),
                            child: const Icon(Icons.edit,
                                size: 16, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      userName, // Dynamically fetched name
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      userEmail, // Dynamically fetched email
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () {},
                      child: const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Rikaz Tools Presets
              _Section(
                title: 'Rikaz Tools Presets',
                count: '${presets.length}/5',
                textColor: textColor,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: addPreset,
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('+',
                                style:
                                    TextStyle(fontSize: 18, color: textColor)),
                            const SizedBox(width: 5),
                            Text(
                              'Add New Preset',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ...presets.map(
                      (preset) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    preset['name'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      _Tag(
                                          text:
                                              '${preset['sensitivity']} Sensitivity'),
                                      _Tag(
                                          text:
                                              '${preset['triggers']} Triggers'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit,
                                      size: 20, color: textColor),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete,
                                      size: 20, color: textColor),
                                  onPressed: () =>
                                      handleDeletePreset(preset['id']),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Settings Section
              _Section(
                title: 'Settings',
                textColor: textColor,
                child: Column(
                  children: [
                    _SettingsItem(
                      icon: Icons.security,
                      label: 'Privacy',
                      textColor: textColor,
                      cardColor: cardColor,
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.help_outline,
                      label: 'Help & Support',
                      textColor: textColor,
                      cardColor: cardColor,
                      onTap: () {},
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.dark_mode, color: textColor, size: 20),
                              const SizedBox(width: 10),
                              Text('Dark Mode',
                                  style: TextStyle(
                                      color: textColor, fontSize: 16)),
                            ],
                          ),
                          Switch(
                            value: isDarkMode,
                            onChanged: (val) => setState(() => isDarkMode = val),
                            activeThumbColor: Colors.blueAccent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Sign Out
              _Section(
                textColor: textColor,
                child: _SettingsItem(
                  icon: Icons.logout,
                  label: 'Sign Out',
                  textColor: textColor,
                  cardColor: cardColor,
                  trailing: Icons.chevron_right,
                  onTap: handleSignOut, // This is now connected to the secure function
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------- Helper Components ---------- */

class _Section extends StatelessWidget {
  final String? title;
  final String? count;
  final Color textColor;
  final Widget child;

  const _Section({
    this.title,
    this.count,
    required this.textColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title!,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor)),
                if (count != null)
                  Text(count!,
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final IconData? trailing;
  final Color textColor;
  final Color cardColor;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.cardColor,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 10),
                Text(label,
                    style: TextStyle(fontSize: 16, color: textColor)),
              ],
            ),
            if (trailing != null) 
              Icon(trailing, color: textColor, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }
}
