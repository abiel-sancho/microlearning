import 'package:flutter/material.dart';
import 'package:testeapp/cores_disciplina.dart';
import 'package:testeapp/favoritos_service.dart';
import 'package:testeapp/resumo.dart';
import 'package:testeapp/tema.dart';

class Favoritos extends StatefulWidget {
  const Favoritos({super.key});

  @override
  State<Favoritos> createState() => _FavoritosState();
}

class _FavoritosState extends State<Favoritos> {
  late Future<List<Map<String, dynamic>>> _futuro = FavoritosService.listar();

  void _recarregar() {
    setState(() {
      _futuro = FavoritosService.listar();
    });
  }

  Future<void> _abrir(Map<String, dynamic> topico) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Resumo(
          idTopico: topico['id'].toString(),
          idDisciplina: topico['id_disciplina']?.toString(),
        ),
      ),
    );
    if (mounted) _recarregar(); // o usuário pode ter desfavoritado lá dentro
  }

  Future<void> _desfavoritar(Map<String, dynamic> topico) async {
    try {
      await FavoritosService.definir(topico['id'].toString(), favorito: false);
      if (mounted) _recarregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível remover: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Não foi possível carregar os favoritos.\n${snapshot.error}',
                      textAlign: TextAlign.center),
                  TextButton(onPressed: _recarregar, child: const Text('Tentar novamente')),
                ],
              ),
            );
          }
          final favoritos = snapshot.data ?? [];
          if (favoritos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Você ainda não favoritou nenhum tópico.\n'
                  'Toque no coração dentro de um resumo para adicionar.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: favoritos.length,
            itemBuilder: (context, i) {
              final topico = favoritos[i];
              final cores = AppTema.daDisciplina(
                corDaDisciplina(topico['id_disciplina']),
                escuro: Theme.of(context).brightness == Brightness.dark,
              ).colorScheme;
              return GestureDetector(
                onTap: () => _abrir(topico),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                  decoration: AppTema.cartao(
                    context,
                    cor: cores.primaryContainer,
                    borda: cores.primary,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${topico['nome']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cores.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remover dos favoritos',
                        icon: Icon(Icons.favorite, color: cores.onPrimaryContainer),
                        onPressed: () => _desfavoritar(topico),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}