import 'dart:developer';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/conversao.dart';
import 'package:testeapp/tema.dart';

class EditarResumoScreen extends StatefulWidget {
  final String idTopico;

  const EditarResumoScreen({super.key, required this.idTopico});

  @override
  State<EditarResumoScreen> createState() => _EditarResumoScreenState();
}

class _EditarResumoScreenState extends State<EditarResumoScreen> {
  QuillController? _controller; // Nullable porque começa carregando
  final TextEditingController _tituloController = TextEditingController();
  
  String? _selectedValue;
  bool _isLoadingData = true; // Para saber se estamos buscando o banco

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  // Função para buscar o Tópico no Supabase e popular a tela
  Future<void> _carregarDados() async {
    try {
      final response = await Supabase.instance.client
          .from('topico')
          .select()
          .eq('id', widget.idTopico)
          .single();

      _tituloController.text = response['nome'];
      _selectedValue = response['id_disciplina'].toString();
      
      String markdownBanco = response['texto'] ?? '';

      // Converte o Markdown armazenado para um Document do Quill
      final document = Conversao.markdownToDeltaDoc(markdownBanco);

      _controller = QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
      );

      setState(() {
        _isLoadingData = false;
      });
    } catch (e) {
      log("Erro ao carregar dados: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar o resumo para edição.')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchDropdownData() async {
    return await Supabase.instance.client
        .from('disciplina')
        .select('id, nome')
        .order('nome', ascending: true);
  }

  void insertImage(QuillController controller, String url) {
    final sel = controller.selection;
    final index = sel.start < 0 ? controller.document.length - 1 : sel.start;

    controller.replaceText(
      index,
      sel.end - sel.start,
      BlockEmbed.image(url),
      null,
    );
    controller.moveCursorToPosition(index + 1);
  }

  Future<String> uploadImageToSupabase(String caminho) async {
    if (caminho.startsWith('http')) return caminho;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw StateError('Usuário não logado.');

    final bytes = await XFile(caminho).readAsBytes();

    final ehPng = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
    final ext = ehPng ? 'png' : 'jpg';

    final nome = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storage = Supabase.instance.client.storage.from('imagens_resumos');

    await storage.uploadBinary(
      nome,
      bytes,
      fileOptions: FileOptions(contentType: ehPng ? 'image/png' : 'image/jpeg'),
    );

    return storage.getPublicUrl(nome);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _tituloController.dispose();
    super.dispose();
  }

  Future<void> _atualizarConteudo() async {
    if (_controller == null) return;

    try {
      // Pega o Delta editado e converte de volta pra Markdown
      final List<dynamic> deltaJson = _controller!.document.toDelta().toJson();
      final String markdownFinal = Conversao.deltaToMarkdown(deltaJson);

      // Faz o UPDATE (não INSERT) no Supabase
      await Supabase.instance.client.from('topico').update({
        'nome': _tituloController.text,
        'id_disciplina': _selectedValue,
        'texto': markdownFinal,
      }).eq('id', widget.idTopico);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resumo atualizado com sucesso!')),
        );
        Navigator.pop(context); // Volta pra tela anterior
      }
    } catch (e) {
      log("Erro ao atualizar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData || _controller == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchDropdownData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final items = snapshot.data ?? [];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Editar Conteúdo'),
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
            children: [
              const SizedBox(height: 20),
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
              const SizedBox(height: 8),
              TextField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Insira o nome do tópico',
                ),
              ),
              QuillSimpleToolbar(
                controller: _controller!,
                config: QuillSimpleToolbarConfig(
                  embedButtons: FlutterQuillEmbeds.toolbarButtons(
                    videoButtonOptions: null,
                    imageButtonOptions: QuillToolbarImageButtonOptions(
                      imageButtonConfig: QuillToolbarImageConfig(
                        onImageInsertCallback: (image, controller) async {
                          try {
                            final url = await uploadImageToSupabase(image);
                            insertImage(controller, url);
                          } catch (e) {
                            log('Erro ao enviar imagem: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro ao enviar imagem: $e'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ),
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
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTema.cartao(context, sombra: false),
                    child: QuillEditor(
                      controller: _controller!,
                      focusNode: FocusNode(),
                      scrollController: ScrollController(),
                      config: QuillEditorConfig(
                        embedBuilders: kIsWeb
                            ? FlutterQuillEmbeds.editorWebBuilders()
                            : FlutterQuillEmbeds.editorBuilders(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _atualizarConteudo,
            child: const Icon(Icons.save),
          ),
        );
      },
    );
  }
}