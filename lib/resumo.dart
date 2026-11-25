import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:testeapp/cores_disciplina.dart';
import 'package:testeapp/questoes_aluno.dart';
import 'package:testeapp/tema.dart';
import 'package:testeapp/favoritos_service.dart';


class Resumo extends StatefulWidget {

  const Resumo ({super.key, required this.idTopico, this.idDisciplina});

  final String idTopico;

  /// Só serve para escolher a cor da tela. Quando a tela é aberta sem ela (pelo
  /// painel de revisões do início, por exemplo), a disciplina do tópico é
  /// descoberta junto com o nome.
  final String? idDisciplina;

  @override
  State<Resumo> createState() => _ResumoState();
}


class _ResumoState extends State<Resumo> {

    bool _favorito = false;

  @override
  void initState() {
    super.initState();
    FavoritosService.ehFavorito(widget.idTopico).then((valor) {
      if (mounted) setState(() => _favorito = valor);
    }).catchError((_) {});
  }

  Future<void> _alternarFavorito() async {
    final novo = !_favorito;
    setState(() => _favorito = novo); // mostra na hora
    try {
      await FavoritosService.definir(widget.idTopico, favorito: novo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _favorito = !novo); // desfaz se falhou
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível atualizar os favoritos: $e')),
      );
    }
  }

  late final _resumoStream = Supabase.instance.client
    .from('topico')
    .stream(primaryKey: ['id'])
    .eq('id', widget.idTopico,);

  late final Future<Map<String, dynamic>> _topicoFuture = Supabase.instance.client
      .from('topico')
      .select('nome, id_disciplina')
      .eq('id', widget.idTopico)
      .single();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _topicoFuture,
      builder: (context, topicoSnapshot) {
        // A tela usa a cor da disciplina a que o tópico pertence.
        final idDisciplina = widget.idDisciplina ?? topicoSnapshot.data?['id_disciplina'];
        final tema = idDisciplina == null
            ? Theme.of(context)
            : AppTema.daDisciplina(corDaDisciplina(idDisciplina),
              escuro: Theme.of(context).brightness == Brightness.dark,);
              
        return Theme(
          data: tema,
          child: Scaffold (
      appBar: AppBar(
        leading: IconButton(onPressed:() {Navigator.pop(context);}, icon: Icon(Icons.arrow_back)),
        title: Text((topicoSnapshot.data?['nome'] ?? '').toString()),
        actions: [
          IconButton(
            tooltip: _favorito ? 'Remover dos favoritos' : 'Favoritar',
            icon: Icon(_favorito ? Icons.favorite : Icons.favorite_border),
            onPressed: _alternarFavorito,
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _resumoStream,
        builder: (context, snapshot) {
          if (!snapshot. hasData) {
            return const Center(child: CircularProgressIndicator());
          }else{
            if(snapshot.data == null || snapshot.data!.isEmpty){
 return Center(child: Markdown(styleSheet: AppTema.markdown(context), data: '# Ainda não tem nenhum resumo aqui!'),);
            }
            else{
          final resumo = snapshot.data!;
          final texto = (resumo[0]['texto'] ?? '').toString().trim();

          return Column(
            children: [
              Expanded(
                child: Markdown(
                  styleSheet: AppTema.markdown(context),
                  data: texto.isEmpty ? '*Este tópico ainda não tem texto.*' : texto,
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuestoesAluno(idTopico: widget.idTopico),
                          ),
                        );
                      },
                      icon: const Icon(Icons.quiz),
                      label: const Text('Ir para as questões'),
                    ),
                  ),
                ),
              ),
            ],
          );
            }
          }
        },
      ),
          ),
        );
      },
    );
  }
}
