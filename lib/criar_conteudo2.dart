/*import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delta_markdown/delta_markdown.dart'; // Importação do novo pacote

class CriarConteudoScreen extends StatefulWidget {
  const CriarConteudoScreen({super.key});

  @override
  State<CriarConteudoScreen> createState() => _CriarConteudoScreenState();
}

class _CriarConteudoScreenState extends State<CriarConteudoScreen> {
  late QuillController _controller;
  // 1. Controlador para capturar o texto digitado no TextField
  final TextEditingController _nomeController = TextEditingController();

  String? _selectedValue;
  bool _isLoading = false; // Controle de estado para o botão de salvar

  Future<List<Map<String, dynamic>>> fetchDropdownData() async {
    final response = await Supabase.instance.client
        .from('disciplina')
        .select('id, nome')
        .order('nome', ascending: true);
    
    return response;
  }
  
  @override
  void initState() {
    super.initState();
    _controller = QuillController.basic();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nomeController.dispose(); // 2. Descartando o controlador para evitar memory leaks
    super.dispose();
  }

  // 3. Função responsável por salvar os dados no Supabase
  Future<void> _salvarConteudo() async {
    final nomeTopico = _nomeController.text.trim();

    // Validações básicas para garantir que os dados não estão vazios
    if (nomeTopico.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira o nome do tópico.')),
      );
      return;
    }
    if (_selectedValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma disciplina.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Converte o texto do Quill (Delta) para uma String JSON e depois para Markdown
      final deltaJsonString = jsonEncode(_controller.document.toDelta().toJson());
      //final textoMarkdown = deltaToMarkdown(deltaJsonString);

      // Descobre se o ID da disciplina no seu banco é INT ou UUID/String e converte se necessário
      final disciplinaId = int.tryParse(_selectedValue!) ?? _selectedValue;

      // Realiza a inserção no Supabase na tabela "topico"
      await Supabase.instance.client.from('topico').insert({
        'nome': nomeTopico,
        'id_disciplina': disciplinaId,
        'texto': textoMarkdown,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conteúdo salvo com sucesso!')),
      );

      // Opcional: Limpa os campos após o salvamento ser bem-sucedido
      _nomeController.clear();
      _controller.clear();
      setState(() {
        _selectedValue = null;
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchDropdownData(),
      builder: (context, snapshot) {
        // Envolvi o carregamento e o erro em Scaffolds para evitar telas pretas/vermelhas sem formatação
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Erro: ${snapshot.error}')));
        }

        final items = snapshot.data ?? [];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Criar Conteúdo'),
            elevation: 0,
          ),
          body: Column(
            children: [
              const SizedBox(height: 20,),
              DropdownButton<String>(
                value: _selectedValue,
                hint: const Text("Selecione uma disciplina"),
                isExpanded: true,
                items: items.map((item) {
                  return DropdownMenuItem<String>(
                    value: item['id'].toString(),
                    child: Text(item['nome']),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedValue = newValue;
                  });
                },
              ),
              const SizedBox(height: 8,),
              TextField(
                controller: _nomeController, // 4. TextField agora tem seu texto guardado aqui
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Insira o nome do novo tópico',
                ),
              ),
              QuillSimpleToolbar(
                controller: _controller,
                config: const QuillSimpleToolbarConfig(
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
            // 5. Aciona o botão ou desabilita se estiver carregando
            onPressed: _isLoading ? null : _salvarConteudo,
            child: _isLoading 
                ? const SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                  ) 
                : const Icon(Icons.save),
          ),
        );
      }
    );
  }
}*/