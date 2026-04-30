import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
//import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/conversao.dart';

class CriarConteudoScreen extends StatefulWidget {
  const CriarConteudoScreen({super.key});

  @override
  State<CriarConteudoScreen> createState() => _CriarConteudoScreenState();
}

class _CriarConteudoScreenState extends State<CriarConteudoScreen> {
  late QuillController _controller;
  final TextEditingController _tituloController = TextEditingController();
  User? user;
  Supabase? supabase;
  Future<List<Map<String, dynamic>>> fetchDropdownData() async {
    final response = await Supabase.instance.client
        .from('disciplina')
        .select('id, nome') // Busque apenas o ID e o Nome que deseja exibir
        .order('nome', ascending: true); // Opcional: ordenar alfabeticamente

    return response;
  }

  String? _selectedValue;

  @override
  void initState() {
    super.initState();
    user = Supabase.instance.client.auth.currentUser;
    supabase = Supabase.instance;
    log(user.toString());
    _controller = QuillController.basic();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchDropdownData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              height: 50,
              width: 50,
              child: const CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Text('Erro: ${snapshot.error}');
        }

        final items = snapshot.data ?? [];

        return Scaffold(
          appBar: AppBar(title: const Text('Criar Conteúdo'), elevation: 0),
          body: Column(
            children: [
              SizedBox(height: 20),
              DropdownButton<String>(
                value: _selectedValue,
                hint: const Text("Selecione uma disciplina"),
                isExpanded: true, // Ocupa toda a largura disponível
                items: items.map((item) {
                  return DropdownMenuItem<String>(
                    value: item['id']
                        .toString(), // O ID que será salvo no estado
                    child: Text(item['nome']), // O texto que aparece no app
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedValue = newValue;
                  });
                },
              ),
              SizedBox(height: 8),
              TextField(
                controller: _tituloController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Insira o nome do novo tópico',
                ),
              ),
              QuillSimpleToolbar(
                controller: _controller,
                config: QuillSimpleToolbarConfig(
                  showBackgroundColorButton: false,
                  showAlignmentButtons: false,
                  showFontFamily: false,
                  showFontSize: false,
                  showSubscript: false,
                  showSuperscript: false,
                  showColorButton: false,
                  showListCheck: false,
                  showInlineCode: false,
                  showCodeBlock: false,
                  showStrikeThrough: false,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(),
                    ),
                    child: QuillEditor(
                      controller: _controller,
                      focusNode: FocusNode(),
                      scrollController: ScrollController(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              // 1. Validação simples antes de tentar salvar
              if (_tituloController.text.trim().isEmpty ||
                  _selectedValue == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Por favor, informe o título e selecione uma disciplina.',
                    ),
                  ),
                );
                return;
              }

              try {
                // 2. Pega o JSON do editor
                final List<dynamic> deltaJson = _controller.document
                    .toDelta()
                    .toJson();

                // 3. Converte usando a função manual acima
                final String markdownFinal = Conversao.deltaToMarkdown(
                  deltaJson,
                );

                // 4. Salva no Supabase aguardando a resposta com 'await'
                await supabase!.client.from('topico').insert({
                  'nome': _tituloController.text,
                  'id_disciplina': _selectedValue,
                  'texto': markdownFinal,
                  'uid_professor': user!.id,
                });

                log("Markdown gerado: $markdownFinal");

                // 5. Exibe a mensagem de sucesso
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Conteúdo salvo com sucesso!'),
                    ),
                  );
                  Navigator.pop(context); // Fecha a tela de criação
                }
              } catch (e) {
                // 6. Se algo der errado, mostra o erro na tela em vez de falhar em silêncio
                log("Erro ao salvar no banco: $e");
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
                }
              }
            },
            child: const Icon(Icons.save),
          ),
        );
      },
    );
  }
}
