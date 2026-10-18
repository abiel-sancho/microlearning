//import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CriarQuestao extends StatefulWidget{
  const CriarQuestao({super.key, required this.idTopico});

  final String idTopico;

  @override
  State<CriarQuestao> createState() => _CriarQuestaoState();
}

class _CriarQuestaoState extends State<CriarQuestao> {
  String? _respostaCorreta;
  final TextEditingController _enunciadoController = TextEditingController();
  final TextEditingController _alternativaAController = TextEditingController();
  final TextEditingController _alternativaBController = TextEditingController();
  final TextEditingController _alternativaCController = TextEditingController();
  final TextEditingController _alternativaDController = TextEditingController();

  @override
  void dispose() {
    _enunciadoController.dispose();
    _alternativaAController.dispose();
    _alternativaBController.dispose();
    _alternativaCController.dispose();
    _alternativaDController.dispose();
    super.dispose();
  }

  Future<void> _salvarQuestao() async {
    if (_enunciadoController.text.trim().isEmpty ||
        _alternativaAController.text.trim().isEmpty ||
        _alternativaBController.text.trim().isEmpty ||
        _alternativaCController.text.trim().isEmpty ||
        _alternativaDController.text.trim().isEmpty ||
        _respostaCorreta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos e selecione a alternativa correta.')),
      );
      return;
    }

    try {
      await Supabase.instance.client.from('questoes').insert({
        'id_topico': widget.idTopico,
        'enunciado': _enunciadoController.text.trim(),
        'alt_a': _alternativaAController.text.trim(),
        'alt_b': _alternativaBController.text.trim(),
        'alt_c': _alternativaCController.text.trim(),
        'alt_d': _alternativaDController.text.trim(),
        'alt_correta': _respostaCorreta,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Questão salva com sucesso.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar a questão: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: Text("Criar questão"),),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 30,),
            TextField(
              controller: _enunciadoController,
              minLines: 3,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: "Insira o enunciado da questão",
              ),
            ),
            SizedBox(height: 20),

            TextField(
              controller: _alternativaAController,
              
              minLines: 1,
              maxLines: 2,
              decoration: InputDecoration(
                prefixIcon: Padding(padding: EdgeInsets.all(7), child: Text('a) ', style: TextStyle(fontSize: 16),))
              ),
            ),
            SizedBox(height: 10,),

            TextField(
              controller: _alternativaBController,
              minLines: 1,
              maxLines: 2,
              decoration: InputDecoration(
                prefixIcon: Padding(padding: EdgeInsets.all(7), child: Text('b) ', style: TextStyle(fontSize: 16),))
              ),
            ),
            SizedBox(height: 10,),

            TextField(
              controller: _alternativaCController,
              minLines: 1,
              maxLines: 2,
              decoration: InputDecoration(
                prefixIcon: Padding(padding: EdgeInsets.all(7), child: Text('c) ', style: TextStyle(fontSize: 16),))
              ),
            ),
            SizedBox(height: 10,),

            TextField(
              controller: _alternativaDController,
              minLines: 1,
              maxLines: 2,
              decoration: InputDecoration(
                prefixIcon: Padding(padding: EdgeInsets.all(7), child: Text('d) ', style: TextStyle(fontSize: 16),))
              ),
            ),
            SizedBox(height: 30,),

            Text("Selecione a alternativa correta:"),
            SizedBox(height: 10,),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['a', 'b', 'c', 'd'].map((opcao) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
                      value: opcao,
                      groupValue: _respostaCorreta,
                      onChanged: (value) {
                        setState(() => _respostaCorreta = value);
                      },
                    ),
                    Text('$opcao)'),
                  ],
                );
              }).toList(),
            ),

            


            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _salvarQuestao,
              icon: const Icon(Icons.save),
              label: const Text('Salvar questão'),
            ),
          ],
        ),
      )
    );
  }
}