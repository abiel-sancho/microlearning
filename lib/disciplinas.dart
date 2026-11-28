import 'package:flutter/material.dart';
import 'package:testeapp/configuracoes.dart';
import 'package:testeapp/cores_disciplina.dart';
import 'package:testeapp/menu_lateral.dart';
import 'package:testeapp/topicos.dart';
import 'package:testeapp/tema.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testeapp/icones_disciplina.dart';

class Disciplinas extends StatefulWidget {
  const Disciplinas({super.key});

  @override
  State<Disciplinas> createState() => _DisciplinasState();
}

/// Uma área do ENEM com as suas disciplinas (para desenhar a grade por área).
class _GrupoArea {
  _GrupoArea(this.nome);
  final String nome;
  final List<Map<String, dynamic>> disciplinas = [];
}

/// Grade de Disciplinas por faixa de largura (Material 3, window size
/// classes): no celular fica como antes (2 colunas, ícone 100); em tela
/// maior, mais colunas, ícone menor e cartão mais baixo que largo.
class _Grade {
  const _Grade(this.colunas, this.icone, this.proporcao);
  final int colunas;
  final double icone;
  final double proporcao; // largura ÷ altura do cartão

  static _Grade paraLargura(double largura) {
    if (largura < 600) return const _Grade(2, 100, 1.0); // compacta: celular
    if (largura < 840) return const _Grade(3, 72, 1.1); // média: tablet, janela pequena
    return const _Grade(4, 64, 1.3); // expandida: web e desktop
  }
}

class _DisciplinasState extends State<Disciplinas> {
  final _supabase = Supabase.instance.client;
  final user = Supabase.instance.client.auth.currentUser;

  // Disciplinas do professor (`professor_disciplinas`), para o selo.
  // Foto, nome e papel ficam no menu lateral (`menu_lateral.dart`, etapa 33).
  Set<int> _minhasDisciplinas = {};

  // Disciplinas agrupadas por área.
  late Future<List<_GrupoArea>> _futuroAreas = _carregarDisciplinas();

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  // ---------------------------------------------------------------------------
  // Dados
  // ---------------------------------------------------------------------------

  /// Busca as disciplinas com o nome da área, já na ordem do mapa de conteúdos,
  /// e agrupa por área.
  Future<List<_GrupoArea>> _carregarDisciplinas() async {
    final linhas = await _supabase
        .from('disciplinas')
        .select('id, sigla, nome, area_id, areas(nome)')
        // ascending: true é obrigatório: no supabase_flutter o padrão do
        // .order() é decrescente (as áreas vinham de trás para frente).
        .order('area_id', ascending: true)
        .order('id', ascending: true);

    final grupos = <int, _GrupoArea>{};
    for (final disciplina in linhas) {
      final areaId = disciplina['area_id'] as int;
      final area = disciplina['areas'] as Map<String, dynamic>?;
      grupos
          .putIfAbsent(areaId, () => _GrupoArea(area?['nome'] as String? ?? 'Outras'))
          .disciplinas
          .add(disciplina);
    }
    return grupos.values.toList();
  }

  /// Papel em `perfis`; para professor, as disciplinas dele (selo).
  Future<void> _carregarPerfil() async {
    final usuario = user;
    if (usuario == null) return;
    try {
      final perfil = await _supabase
          .from('perfis')
          .select('papel')
          .eq('id', usuario.id)
          .maybeSingle();

      var minhas = <int>{};
      if (perfil?['papel'] == 'professor') {
        final vinculos = await _supabase
            .from('professor_disciplinas')
            .select('disciplina_id')
            .eq('professor_id', usuario.id);
        minhas = {for (final v in vinculos) v['disciplina_id'] as int};
      }

      if (!mounted) return;
      setState(() => _minhasDisciplinas = minhas);
    } catch (erro, pilha) {
      // Sem o perfil, a tela continua, só sem o selo "Minha disciplina".
      debugPrint('Erro ao carregar o perfil: $erro\n$pilha');
    }
  }

  void _tentarDeNovo() {
    setState(() => _futuroAreas = _carregarDisciplinas());
  }

  // ---------------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Menu lateral comum (etapa 33), com Sair.
      endDrawer: const MenuLateral(naTelaDeDisciplinas: true),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Disciplinas'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: (index) async {
          if (index == 0) {
            // Home: volta para a tela Início (que está logo abaixo na pilha).
            Navigator.pop(context);
          } else if (index == 1) {
            // A foto é relida pelo menu lateral cada vez que ele abre.
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => Configuracoes()),
            );
          }
          // index 2 (Favoritos): ainda sem ação. Pendente de decisão.
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Configurações"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Favoritos"),
        ],
      ),
      body: FutureBuilder<List<_GrupoArea>>(
        future: _futuroAreas,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Erro ao carregar disciplinas: ${snapshot.error}');
            return _erroAoCarregar(context);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final areas = snapshot.data!;
          // Largura real da coluna do app (até 1000 px, ver main.dart).
          return LayoutBuilder(builder: (context, limites) {
            final grade = _Grade.paraLargura(limites.maxWidth);
            return CustomScrollView(
              primary: false,
              slivers: <Widget>[
                for (final area in areas) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        area.nome,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: grade.colunas,
                        mainAxisSpacing: 10.0,
                        crossAxisSpacing: 10.0,
                        childAspectRatio: grade.proporcao,
                      ),
                      itemCount: area.disciplinas.length,
                      itemBuilder: (context, index) =>
                          _cartaoDisciplina(context, area.disciplinas[index], grade.icone),
                    ),
                  ),
                ],
                const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
              ],
            );
          });
        },
      ),
    );
  }

  /// Card de uma disciplina: mesmo visual de antes (nome + ícone grande),
  /// com o selo "Minha disciplina" para o professor vinculado a ela.
  /// No computador, o cartão sobe um pouco com o mouse em cima e o cursor
  /// vira a mãozinha (`_RespostaAoMouse`); no toque, nada muda.
  Widget _cartaoDisciplina(
      BuildContext context, Map<String, dynamic> disciplina, double tamanhoIcone) {
    final cores = Theme.of(context).colorScheme;
    final minha = _minhasDisciplinas.contains(disciplina['id']);
    // Cor da disciplina (etapa 35). Fundo e texto são um par calculado pelo
    // Material 3 (primaryContainer / onPrimaryContainer), com contraste.
    // Sigla desconhecida: as cores do app, como antes.
    final esquema = esquemaDaDisciplina(disciplina['sigla']);
    final fundo = esquema?.primaryContainer ?? cores.secondaryContainer;
    final texto = esquema?.onPrimaryContainer ?? cores.onSecondaryContainer;
    final icone = esquema?.onPrimaryContainer.withValues(alpha: 0.75) ??
        cores.secondary.withValues(alpha: 0.6);

    return _RespostaAoMouse(
      child: GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Topicos(
              idDisciplina: disciplina['id'].toString(),
              sigla: disciplina['sigla'] as String?,
            ),
          ),
        );
      },
      child: Container(
        decoration: AppTema.cartao(
          context,
          cor: fundo,
        ),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      disciplina['nome'],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: texto,
                          ),
                    ),
                  ),
                  Icon(
                    iconeDaDisciplina(disciplina),
                    size: tamanhoIcone,
                    color: icone,
                  ),
                ],
              ),
            ),
            if (minha)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    // Selo invertido (texto na cor do fundo): sempre legível.
                    color: esquema?.onPrimaryContainer ?? cores.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Minha disciplina',
                    style: TextStyle(fontSize: 10, color: esquema != null ? fundo : cores.onPrimary),
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _erroAoCarregar(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Não foi possível carregar as disciplinas.\nVerifique sua internet e tente de novo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _tentarDeNovo,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resposta ao mouse (web e desktop): cursor de clique e o cartão sobe
/// um pouco (1,5% da altura) e cresce 3% enquanto o mouse está em cima.
class _RespostaAoMouse extends StatefulWidget {
  const _RespostaAoMouse({required this.child});
  final Widget child;

  @override
  State<_RespostaAoMouse> createState() => _RespostaAoMouseState();
}

class _RespostaAoMouseState extends State<_RespostaAoMouse> {
  bool _emCima = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _emCima = true),
      onExit: (_) => setState(() => _emCima = false),
      child: AnimatedSlide(
        offset: _emCima ? const Offset(0, -0.015) : Offset.zero,
        duration: const Duration(milliseconds: 150),
        child: AnimatedScale(
          scale: _emCima ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: widget.child,
        ),
      ),
    );
  }
}
