import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class CriarConteudoScreen extends StatefulWidget {
  const CriarConteudoScreen({super.key});

  @override
  State<CriarConteudoScreen> createState() => _CriarConteudoScreenState();
}

class _CriarConteudoScreenState extends State<CriarConteudoScreen> {
  late QuillController _controller;

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
        return const CircularProgressIndicator();
      }

      if (snapshot.hasError) {
        return Text('Erro: ${snapshot.error}');
      }

      final items = snapshot.data ?? [];

      return Scaffold(
        appBar: AppBar(
          title: const Text('Criar Conteúdo'),
          elevation: 0,
        ),
        body: Column(
          children: [
            SizedBox(height: 20,),
            DropdownButton<String>(
              value: _selectedValue,
              hint: const Text("Selecione uma disciplina"),
              isExpanded: true, // Ocupa toda a largura disponível
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item['id'].toString(), // O ID que será salvo no estado
                  child: Text(item['nome']), // O texto que aparece no app
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedValue = newValue;
                });
              },
            ),
            SizedBox(height: 8,),
            TextField(
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
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: QuillEditor(
                  controller: _controller,
                  focusNode: FocusNode(),
                  scrollController: ScrollController(),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            final content = jsonEncode(_controller.document.toDelta().toJson());
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Conteúdo salvo: $content')),
            );
          },
          child: const Icon(Icons.save),
        ),
      );
    });
  }
}