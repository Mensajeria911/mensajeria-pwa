/// Tonos que cada usuario puede elegir, agrupados por género.
class Tone {
  const Tone(this.id, this.label, this.genre);
  final String id;
  final String label;
  final String genre;
}

const tones = <Tone>[
  Tone('tono_firma_911', 'Firma 911', 'Marca 911'),
  Tone('tono_servicio_retirado', 'Servicio retirado', 'Marca 911'),
  Tone('tono_servicio_actualizado', 'Servicio actualizado', 'Marca 911'),
  Tone('tono_entrega_completada', 'Entrega completada', 'Marca 911'),
  Tone('tono_solicitud_entrante', 'Solicitud entrante', 'Estilo app de transporte'),
  Tone('tono_conductor_listo', 'Conductor listo', 'Estilo app de transporte'),
  Tone('tono_arranque', 'Arranque', 'Estilo app de transporte'),
  Tone('tono_match', 'Match', 'Trompeta y fanfarria'),
  Tone('tono_heraldo', 'Heraldo', 'Trompeta y fanfarria'),
  Tone('tono_triple_metal', 'Triple metal', 'Trompeta y fanfarria'),
  Tone('tono_metales_de_salsa', 'Metales de salsa', 'Salsa y latino'),
  Tone('tono_cumbia', 'Cumbia', 'Salsa y latino'),
  Tone('tono_mariachi', 'Mariachi', 'Salsa y latino'),
  Tone('tono_dembow', 'Dembow', 'Urbano'),
  Tone('tono_trap', 'Trap', 'Urbano'),
  Tone('tono_house', 'House', 'Electrónica'),
  Tone('tono_subida', 'Subida', 'Electrónica'),
  Tone('tono_sintetizador', 'Sintetizador', 'Electrónica'),
  Tone('tono_cristal', 'Cristal', 'Digital y tecnológico'),
  Tone('tono_pulso_digital', 'Pulso digital', 'Digital y tecnológico'),
  Tone('tono_pulso_ascendente', 'Pulso ascendente', 'Digital y tecnológico'),
  Tone('tono_moneda_propia', 'Moneda propia', 'Retro 8 bits'),
  Tone('tono_nivel_listo', 'Nivel listo', 'Retro 8 bits'),
  Tone('tono_pedido_arcade', 'Pedido arcade', 'Retro 8 bits'),
  Tone('tono_campana_ascendente', 'Campana ascendente', 'Campanas'),
  Tone('tono_recepcion', 'Recepción', 'Campanas'),
  Tone('tono_campanilla', 'Campanilla', 'Campanas'),
  Tone('tono_marimba_rapida', 'Marimba rápida', 'Marimba y madera'),
  Tone('tono_kalimba', 'Kalimba', 'Marimba y madera'),
  Tone('tono_notas_suaves', 'Notas suaves', 'Marimba y madera'),
  Tone('tono_guitarra', 'Guitarra', 'Acústico'),
  Tone('tono_rasgueo', 'Rasgueo', 'Acústico'),
  Tone('tono_piano_electrico', 'Piano eléctrico', 'Jazz'),
  Tone('tono_trompeta_con_sordina', 'Trompeta con sordina', 'Jazz'),
  Tone('tono_cuerdas', 'Cuerdas', 'Orquestal'),
  Tone('tono_pizzicato', 'Pizzicato', 'Orquestal'),
  Tone('tono_timbal_y_metales', 'Timbal y metales', 'Orquestal'),
  Tone('tono_congas', 'Congas', 'Percusión'),
  Tone('tono_claves', 'Claves', 'Percusión'),
  Tone('tono_timbre_urgente', 'Timbre urgente', 'Alarma y urgente'),
  Tone('tono_sirena_corta', 'Sirena corta', 'Alarma y urgente'),
  Tone('tono_alerta_doble', 'Alerta doble', 'Alarma y urgente'),
];
