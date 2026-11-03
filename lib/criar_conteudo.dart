import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
//import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/conversao.dart';
import 'package:testeapp/criar_questao.dart';
import 'package:testeapp/tema.dart';

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
        .order('nome', ascending: true);

    return response;
  }

  String? _selectedValue;

  // Questões criadas nesta tela. Ficam só em memória até o professor salvar o
  // conteúdo; só então são gravadas, ligadas ao id do tópico recém-criado.
  final List<Map<String, dynamic>> _questoes = [];
  bool get maximoDeQuestoes => _questoes.length >= 4;
  bool _salvando = false;
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
                children: [
                  SizedBox(height: 20),
                  DropdownButton<String>(
                    value: _selectedValue,
                    hint: const Text("Selecione uma disciplina"),
                    isExpanded: true,
                    items: items.map((item) {
                      return DropdownMenuItem<String>(
                        value: item['id']
                            .toString(),
                        child: Text(item['nome']),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTema.cartao(context, sombra: false),
                        child: QuillEditor(
                          controller: _controller,
                          focusNode: FocusNode(),
                          scrollController: ScrollController(),
                        ),
                      ),
                    ),

                    Column(
                      children: [
                        ListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            ListTile(
                              enabled: !maximoDeQuestoes,
                              leading: Icon(Icons.add),
                              title: Text("Adicionar questão"),
                              onTap: () async {
                                // Não grava nada agora: a tela devolve os dados da
                                // questão e eles só vão para o banco ao salvar o conteúdo.
                                final questao = await Navigator.push<Map<String, dynamic>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CriarQuestao(),
                                  ),
                                );

                                if (questao == null || !mounted) return;
                                setState(() => _questoes.add(questao));
                              },
                            ),
                          ],
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _questoes.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: Text((index+1).toString()),
                              title: Text(
                                _questoes[index]['enunciado'].toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            );
                          },
                          )
                      ],
                    )
                ],
              ),
          ),


          floatingActionButton: FloatingActionButton(
            onPressed: () async {
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

              if (_salvando) return;
              _salvando = true;

              try {
                final List<dynamic> deltaJson = _controller.document
                    .toDelta()
                    .toJson();


                final String markdownFinal = Conversao.deltaToMarkdown(
                  deltaJson,
                );


                // Cria o tópico (uma única vez) e já pega o id gerado pelo banco.
                final topico = await supabase!.client
                    .from('topico')
                    .insert({
                      'nome': _tituloController.text,
                      'id_disciplina': _selectedValue,
                      'texto': markdownFinal,
                      'uid_professor': user!.id,
                    })
                    .select('id')
                    .single();

                // As questões são gravadas ligadas ao id do tópico recém-criado.
                if (_questoes.isNotEmpty) {
                  try {
                    await supabase!.client.from('questoes').insert([
                      for (final questao in _questoes)
                        {...questao, 'id_topico': topico['id']},
                    ]);
                  } catch (_) {
                    // Não deixa um tópico sem as questões: desfaz a criação dele.
                    try {
                      await supabase!.client
                          .from('topico')
                          .delete()
                          .eq('id', topico['id']);
                    } catch (_) {
                      // Se nem o desfazer funcionar, o erro original ainda é mostrado.
                    }
                    rethrow;
                  }
                }

                log("Markdown gerado: $markdownFinal");


                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Conteúdo salvo com sucesso!'),
                    ),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                log("Erro ao salvar no banco: $e");
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
                }
              } finally {
                _salvando = false;
              }
            },
            child: const Icon(Icons.save),
          ),
        );
      },
    );
  }
}