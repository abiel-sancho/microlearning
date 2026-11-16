import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/resumo.dart';
import 'package:testeapp/tema.dart';
import 'package:testeapp/cores_disciplina.dart';


class Topicos extends StatefulWidget {
  const Topicos ({super.key, required this.idDisciplina, required this.nomeDisciplina});

  final String idDisciplina;
  final String nomeDisciplina;

  @override

  State<Topicos> createState() => _TopicosState();
}

class _TopicosState extends State<Topicos> {

  late final _topicoStream = Supabase.instance.client
      .from('topico')
      .stream(primaryKey: ['id'])
      .eq('id_disciplina', widget.idDisciplina);

  // Para cada tópico: data da última revisão e quantidade de questões.
  Map<String, String> _ultimaRevisao = {};
  Map<String, int> _qtdQuestoes = {};

  @override
  void initState() {
    super.initState();
    _carregarInfo();
  }

  Future<void> _carregarInfo() async {
    try {
      final client = Supabase.instance.client;
      final topicos = await client
          .from('topico')
          .select('id')
          .eq('id_disciplina', widget.idDisciplina);
      final ids = [for (final t in topicos) t['id']];
      if (ids.isEmpty) return;

      final questoes =
          await client.from('questoes')
          .select('id_topico')
          .inFilter('id_topico', ids);
      
      final contagem = <String, int>{};

      for (final q in questoes) {
        final id = q['id_topico'].toString();
        contagem[id] = (contagem[id] ?? 0) + 1;
      }

      final revisoes = <String, String>{};
      final usuario = client.auth.currentUser;
      if (usuario != null) {
        final dados = await client
            .from('revisao_topico')
            .select('id_topico, ultima_revisao')
            .eq('user_id', usuario.id)
            .inFilter('id_topico', ids);
        for (final r in dados) {
          final data = r['ultima_revisao'];
          if (data != null) revisoes[r['id_topico'].toString()] = data.toString();
        }
      }

      if (!mounted) return;
      setState(() {
        _qtdQuestoes = contagem;
        _ultimaRevisao = revisoes;
      });
    } catch (e) {
      debugPrint('Erro ao carregar informações dos tópicos: $e');
    }
  }

  String _textoRevisao(String id) {
    final texto = _ultimaRevisao[id];
    final data = texto == null ? null : DateTime.tryParse(texto);
    if (data == null) return 'Não revisado';
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return 'Última revisão: $dia/$mes/${data.year}';
  }

  String _textoQuestoes(String id) {
    final n = _qtdQuestoes[id] ?? 0;
    return n == 1 ? '1 questão' : '$n questões';
  }

  @override

    Widget build(BuildContext context) {
    // A tela inteira usa a cor da disciplina (a mesma do cartão dela).
    return Theme(
      data: AppTema.daDisciplina(corDaDisciplina(widget.idDisciplina),
        escuro: Theme.of(context).brightness == Brightness.dark,),
        
      child: Scaffold(
      appBar: AppBar(leading: IconButton(onPressed:() {Navigator.pop(context);}, icon: Icon(Icons.arrow_back)), title: Text(widget.nomeDisciplina),),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _topicoStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final topico = snapshot.data!;
        return CustomScrollView(
          primary: false,
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  mainAxisSpacing: 10.0,
                  crossAxisSpacing: 10.0,
                  mainAxisExtent: 84,
                ),
                itemCount: topico.length,
                itemBuilder: (context, index) {
                  return 
                    GestureDetector(
                      onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => Resumo(idTopico: topico[index]['id'].toString(), idDisciplina: widget.idDisciplina)));
                      // Ao voltar, o aluno pode ter respondido questões.
                      if (mounted) _carregarInfo();
                    },
                      child: Container(
                        decoration: AppTema.cartao(
                          context,
                          cor: Theme.of(context).colorScheme.primaryContainer,
                          borda: Theme.of(context).colorScheme.primary,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(topico[index]['nome'], 
                            textAlign: TextAlign.start, 
                            maxLines: 2, overflow: TextOverflow.ellipsis, 
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer, 
                              fontWeight: FontWeight.w600,
                              fontSize: 20
                              )),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    _textoRevisao(topico[index]['id'].toString()), 
                                    maxLines: 1, overflow: TextOverflow.ellipsis, 
                                    style: TextStyle(
                                      fontSize: 12, 
                                      color: Theme.of(context).colorScheme.onPrimaryContainer
                                      )
                                    )
                                  ),
                                const SizedBox(width: 8),
                                Text(_textoQuestoes(topico[index]['id'].toString()), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
    );
  }
}