import 'package:flutter/material.dart';
import '../data/quotes_data.dart';
import '../managers/game_storage.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  List<int> _unlockedIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnlockedQuotes();
  }

  Future<void> _loadUnlockedQuotes() async {
    final unlocked = await GameStorage.getUnlockedQuotes();
    if (mounted) {
      setState(() {
        _unlockedIds = unlocked;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Pergaminos de Sabiduría",
          style: TextStyle(color: colors.primary, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.primary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    "Has desbloqueado ${_unlockedIds.length} de ${zenQuotes.length} pergaminos.\nGana partidas para descubrir más.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.primary.withAlpha(160), fontSize: 14),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: zenQuotes.length,
                    itemBuilder: (context, index) {
                      final quote = zenQuotes[index];
                      final isUnlocked = _unlockedIds.contains(quote.id);
                      return _buildQuoteCard(quote, isUnlocked, colors);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildQuoteCard(ZenQuote quote, bool isUnlocked, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isUnlocked ? colors.primary.withAlpha(20) : colors.surface,
        border: Border.all(
          color: isUnlocked ? colors.primary.withAlpha(80) : colors.primary.withAlpha(30),
          width: isUnlocked ? 2 : 1,
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: isUnlocked
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "\"${quote.text}\"",
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "- ${quote.author}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.secondary,
                      ),
                    ),
                  ),
                  if (quote.meaning != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(),
                    ),
                    Text(
                      quote.meaning!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.primary.withAlpha(180),
                      ),
                    ),
                  ],
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: colors.primary.withAlpha(100), size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Pergamino bloqueado...\nGana una partida para revelarlo.",
                      style: TextStyle(color: colors.primary.withAlpha(100), fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
