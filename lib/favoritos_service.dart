import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritosService {
  FavoritosService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<bool> ehFavorito(String idTopico) async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) return false;
    final linha = await _client
        .from('favoritos')
        .select('id_topico')
        .eq('id_usuario', usuario.id)
        .eq('id_topico', idTopico)
        .maybeSingle();
    return linha != null;
  }

  static Future<void> definir(String idTopico, {required bool favorito}) async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) throw StateError('Usuário não logado.');
    if (favorito) {
      await _client.from('favoritos').upsert(
        {'id_usuario': usuario.id, 'id_topico': idTopico},
        onConflict: 'id_usuario,id_topico',
        ignoreDuplicates: true,
      );
    } else {
      await _client
          .from('favoritos')
          .delete()
          .eq('id_usuario', usuario.id)
          .eq('id_topico', idTopico);
    }
  }

  /// Tópicos favoritados pelo usuário, em ordem alfabética.
  static Future<List<Map<String, dynamic>>> listar() async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) return [];
    final dados = await _client
        .from('favoritos')
        .select('topico(id, nome, id_disciplina)')
        .eq('id_usuario', usuario.id);
    final lista = [
      for (final linha in dados)
        if (linha['topico'] is Map)
          Map<String, dynamic>.from(linha['topico'] as Map),
    ];
    lista.sort((a, b) => '${a['nome']}'.toLowerCase().compareTo('${b['nome']}'.toLowerCase()));
    return lista;
  }
}