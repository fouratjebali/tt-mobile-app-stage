import 'package:flutter/material.dart';

class BulkEmailScreen extends StatefulWidget {
  const BulkEmailScreen({super.key});

  @override
  State<BulkEmailScreen> createState() => _BulkEmailScreenState();
}

class _BulkEmailScreenState extends State<BulkEmailScreen> {
  final List<Map<String, String>> recipients = [];

  final TextEditingController subjectController =
  TextEditingController();

  final TextEditingController nameController =
  TextEditingController();

  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController roleController =
  TextEditingController();

  final TextEditingController contextController =
  TextEditingController();

  void addRecipient() {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      recipients.add({
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "role": roleController.text.trim(),
        "context": contextController.text.trim(),
      });

      nameController.clear();
      emailController.clear();
      roleController.clear();
      contextController.clear();
    });
  }

  void generateEmails() {
    if (recipients.isEmpty || subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Ajoutez au moins un destinataire et un sujet.",
          ),
        ),
      );
      return;
    }

    // TODO:
    // Appeler ici l'API backend:
    // POST /bulk/generate

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Génération des emails en cours..."),
      ),
    );
  }

  @override
  void dispose() {
    subjectController.dispose();
    nameController.dispose();
    emailController.dispose();
    roleController.dispose();
    contextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bulk Email"),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Campagne d'e-mails en masse",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              "Sujet général",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                hintText: "Ex: Proposition de collaboration",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Destinataires",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text(
                            "Ajouter un destinataire",
                          ),

                          content: SingleChildScrollView(
                            child: Column(
                              children: [

                                TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: "Nom",
                                  ),
                                ),

                                TextField(
                                  controller: emailController,
                                  decoration: const InputDecoration(
                                    labelText: "Email",
                                  ),
                                ),

                                TextField(
                                  controller: roleController,
                                  decoration: const InputDecoration(
                                    labelText: "Rôle",
                                  ),
                                ),

                                TextField(
                                  controller: contextController,
                                  decoration: const InputDecoration(
                                    labelText: "Contexte",
                                  ),
                                ),
                              ],
                            ),
                          ),

                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text("Annuler"),
                            ),

                            ElevatedButton(
                              onPressed: () {
                                addRecipient();
                                Navigator.pop(context);
                              },
                              child: const Text("Ajouter"),
                            ),
                          ],
                        );
                      },
                    );
                  },

                  icon: const Icon(Icons.add),
                  label: const Text("Ajouter"),
                ),
              ],
            ),

            const SizedBox(height: 15),

            if (recipients.isEmpty)
              const Text(
                "Aucun destinataire ajouté.",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

            ...recipients.asMap().entries.map(
                  (entry) {
                final index = entry.key;
                final recipient = entry.value;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),

                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),

                    title: Text(
                      recipient["name"] ?? "",
                    ),

                    subtitle: Text(
                      "${recipient["email"]}\n"
                          "${recipient["role"]}\n"
                          "${recipient["context"]}",
                    ),

                    isThreeLine: true,

                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          recipients.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: generateEmails,

                icon: const Icon(Icons.auto_awesome),

                label: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    "Générer les emails",
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Prévisualisation",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Les emails générés par l'Agent IA apparaîtront ici.",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}