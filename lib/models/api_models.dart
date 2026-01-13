// Modelo para requisição de login
class LoginRequest {
  final String usuarioLogin;
  final String chaveDeAcesso;

  LoginRequest({
    required this.usuarioLogin,
    required this.chaveDeAcesso,
  });

  Map<String, dynamic> toJson() {
    return {
      'usuarioLogin': usuarioLogin,
      'chaveDeAcesso': chaveDeAcesso,
    };
  }
}

// Modelo para resposta de login
class LoginResponse {
  final bool autenticated;
  final String created;
  final String expiration;
  final String accessToken;
  final String message;

  LoginResponse({
    required this.autenticated,
    required this.created,
    required this.expiration,
    required this.accessToken,
    required this.message,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      autenticated: json['autenticated'] ?? false,
      created: json['created'] ?? '',
      expiration: json['expiration'] ?? '',
      accessToken: json['accessToken'] ?? '',
      message: json['message'] ?? '',
    );
  }

  // Getters para compatibilidade com código antigo
  bool get autenticado => autenticated;
  String get criadoEm => created;
  String get expiraEm => expiration;
  String get token => accessToken;
  String get mensagem => message;
}

// Modelo para Link da API
class ApiLink {
  final String rel;
  final String href;
  final String type;
  final String action;

  ApiLink({
    required this.rel,
    required this.href,
    required this.type,
    required this.action,
  });

  factory ApiLink.fromJson(Map<String, dynamic> json) {
    return ApiLink(
      rel: json['rel'] ?? '',
      href: json['href'] ?? '',
      type: json['type'] ?? '',
      action: json['action'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rel': rel,
      'href': href,
      'type': type,
      'action': action,
    };
  }
}

// Modelo para Evento da API
class EventoApi {
  final int id;
  final String? data_hora_criacao;
  final int id_usuario_criacao;
  final bool deletado;
  final String? data_hora_deletado;
  final int id_usuario;
  final int id_cliente;
  final double valor;
  final String? data_hora_evento;
  final String? data_hora_inicio;
  final String? data_hora_fim;
  final bool confirmado;
  final int prioridade;
  final String? data_hora_confirmado;
  final String? forma_de_pagamento;

  EventoApi({
    this.id = 0,
    this.data_hora_criacao,
    this.id_usuario_criacao = 0,
    this.deletado = false,
    this.data_hora_deletado,
    this.id_usuario = 0,
    this.id_cliente = 0,
    this.valor = 0.0,
    this.data_hora_evento,
    this.data_hora_inicio,
    this.data_hora_fim,
    this.confirmado = false,
    this.prioridade = 0,
    this.data_hora_confirmado,
    this.forma_de_pagamento,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'data_hora_criacao': data_hora_criacao,
      'id_usuario_criacao': id_usuario_criacao,
      'deletado': deletado,
      'data_hora_deletado': data_hora_deletado,
      'id_usuario': id_usuario,
      'id_cliente': id_cliente,
      'valor': valor,
      'data_hora_evento': data_hora_evento ?? data_hora_inicio,
      'data_hora_inicio': data_hora_inicio ?? data_hora_evento,
      'data_hora_fim': data_hora_fim,
      'confirmado': confirmado,
      'prioridade': prioridade,
      'data_hora_confirmado': data_hora_confirmado,
      'forma_de_pagamento': forma_de_pagamento,
    };
  }

  factory EventoApi.fromJson(Map<String, dynamic> json) {
    return EventoApi(
      id: json['id'] ?? 0,
      data_hora_criacao: json['data_hora_criacao'],
      id_usuario_criacao: json['id_usuario_criacao'] ?? 0,
      deletado: json['deletado'] ?? false,
      data_hora_deletado: json['data_hora_deletado'],
      id_usuario: json['id_usuario'] ?? 0,
      id_cliente: json['id_cliente'] ?? 0,
      valor: (json['valor'] ?? 0).toDouble(),
      data_hora_evento: json['data_hora_evento'] ?? json['data_hora_inicio'],
      data_hora_inicio: json['data_hora_inicio'] ?? json['data_hora_evento'],
      data_hora_fim: json['data_hora_fim'],
      confirmado: json['confirmado'] ?? false,
      prioridade: json['prioridade'] ?? 0,
      data_hora_confirmado: json['data_hora_confirmado'],
      forma_de_pagamento: json['forma_de_pagamento'],
    );
  }
}

// Modelo para Cliente da API
class ClienteApi {
  final int id;
  final String nome;
  final String email;
  final String endereco;
  final String telefone;
  final String? data_hora_criacao;
  final int id_usuario_criacao;
  final bool deletado;
  final String? data_hora_deletado;

  ClienteApi({
    this.id = 0,
    required this.nome,
    required this.email,
    required this.endereco,
    required this.telefone,
    this.data_hora_criacao,
    this.id_usuario_criacao = 0,
    this.deletado = false,
    this.data_hora_deletado,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'endereco': endereco,
      'telefone': telefone,
      'data_hora_criacao': data_hora_criacao,
      'id_usuario_criacao': id_usuario_criacao,
      'deletado': deletado,
      'data_hora_deletado': data_hora_deletado,
    };
  }

  factory ClienteApi.fromJson(Map<String, dynamic> json) {
    // Tratar data_hora_criacao - pode ser null ou string
    String? dataHoraCriacao;
    if (json['data_hora_criacao'] != null) {
      if (json['data_hora_criacao'] is String) {
        dataHoraCriacao = json['data_hora_criacao'] as String;
      } else {
        // Se não for string, tentar converter
        try {
          dataHoraCriacao = json['data_hora_criacao'].toString();
        } catch (e) {
          dataHoraCriacao = null;
        }
      }
    }
    
    return ClienteApi(
      id: json['id'] ?? 0,
      nome: json['nome'] ?? '',
      email: json['email'] ?? '',
      endereco: json['endereco'] ?? '',
      telefone: json['telefone'] ?? '',
      data_hora_criacao: dataHoraCriacao,
      id_usuario_criacao: json['id_usuario_criacao'] ?? 0,
      deletado: json['deletado'] ?? false,
      data_hora_deletado: json['data_hora_deletado'],
    );
  }
}

// Modelo para Usuario da API
class UsuarioApi {
  final int id;
  final String nome;
  final String email;
  final String telefone;
  final String senha;
  final String? data_hora_criacao;
  final int id_usuario_criacao;
  final bool deletado;
  final String? data_hora_deletado;

  UsuarioApi({
    this.id = 0,
    required this.nome,
    required this.email,
    required this.telefone,
    this.senha = '',
    this.data_hora_criacao,
    this.id_usuario_criacao = 0,
    this.deletado = false,
    this.data_hora_deletado,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'telefone': telefone,
      'senha': senha,
      'data_hora_criacao': data_hora_criacao,
      'id_usuario_criacao': id_usuario_criacao,
      'deletado': deletado,
      'data_hora_deletado': data_hora_deletado,
    };
  }

  factory UsuarioApi.fromJson(Map<String, dynamic> json) {
    return UsuarioApi(
      id: json['id'] ?? 0,
      nome: json['nome'] ?? '',
      email: json['email'] ?? '',
      telefone: json['telefone'] ?? '',
      senha: json['senha'] ?? '',
      data_hora_criacao: json['data_hora_criacao'],
      id_usuario_criacao: json['id_usuario_criacao'] ?? 0,
      deletado: json['deletado'] ?? false,
      data_hora_deletado: json['data_hora_deletado'],
    );
  }

  UsuarioApi copyWith({
    int? id,
    String? nome,
    String? email,
    String? telefone,
    String? senha,
    String? data_hora_criacao,
    int? id_usuario_criacao,
    bool? deletado,
    String? data_hora_deletado,
  }) {
    return UsuarioApi(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      telefone: telefone ?? this.telefone,
      senha: senha ?? this.senha,
      data_hora_criacao: data_hora_criacao ?? this.data_hora_criacao,
      id_usuario_criacao: id_usuario_criacao ?? this.id_usuario_criacao,
      deletado: deletado ?? this.deletado,
      data_hora_deletado: data_hora_deletado ?? this.data_hora_deletado,
    );
  }
}

// Modelo para Movimentacao da API
class MovimentacaoApi {
  final int id;
  final String nome;
  final int tipo;
  final int id_item;
  final int id_conta;
  final int id_sub_categoria;
  final int id_categoria;
  final int id_emprestimo;
  final int id_cartao;
  final double valor;
  final int id_usuario_criacao;
  final String? data_hora_criacao;
  final bool deletado;
  final String? data_hora_deletado;

  MovimentacaoApi({
    this.id = 0,
    required this.nome,
    this.tipo = 0,
    required this.id_item,
    this.id_conta = 1,
    this.id_sub_categoria = 1,
    this.id_categoria = 1,
    this.id_emprestimo = 1,
    this.id_cartao = 1,
    required this.valor,
    this.id_usuario_criacao = 0,
    this.data_hora_criacao,
    this.deletado = false,
    this.data_hora_deletado,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'tipo': tipo,
      'id_item': id_item,
      'id_conta': id_conta,
      'id_sub_categoria': id_sub_categoria,
      'id_categoria': id_categoria,
      'id_emprestimo': id_emprestimo,
      'id_cartao': id_cartao,
      'valor': valor,
      'id_usuario_criacao': id_usuario_criacao,
      'data_hora_criacao': data_hora_criacao,
      'deletado': deletado,
      'data_hora_deletado': data_hora_deletado,
    };
  }

  factory MovimentacaoApi.fromJson(Map<String, dynamic> json) {
    return MovimentacaoApi(
      id: json['id'] ?? 0,
      nome: json['nome'] ?? '',
      tipo: json['tipo'] ?? 0,
      id_item: json['id_item'] ?? 0,
      id_conta: json['id_conta'] ?? 1,
      id_sub_categoria: json['id_sub_categoria'] ?? 1,
      id_categoria: json['id_categoria'] ?? 1,
      id_emprestimo: json['id_emprestimo'] ?? 1,
      id_cartao: json['id_cartao'] ?? 1,
      valor: (json['valor'] ?? 0).toDouble(),
      id_usuario_criacao: json['id_usuario_criacao'] ?? 0,
      data_hora_criacao: json['data_hora_criacao'],
      deletado: json['deletado'] ?? false,
      data_hora_deletado: json['data_hora_deletado'],
    );
  }
}

// Modelo para Event (novo formato) da API
class EventApi {
  final int id;
  final int id_client;
  final String? date_event;
  final String? week_day;
  final String? hour_event;
  final String? hour_end;
  final String? birthday_person_one;
  final int age_birthday_person_one;
  final String? birthday_person_two;
  final int age_birthday_person_two;
  final int beer;
  final String? beer_brand;
  final String? cake;
  final String? filling;
  final String? candy;
  final String? broth;
  final int cake_with_ice_cream;
  final String? theme;
  final String? image_theme;
  final String? color_balloons;
  final int arc_balloons_type;
  final String? music;
  final String? theme_description;
  final int guests;
  final int courtesy;
  final double signalOne;
  final String? signal_payment;
  final double missing_payment;
  final double amount;
  final String? father_name;
  final String? mother_name;
  final double value_package;
  final double total;
  final int id_user_create;
  final int best_day;
  final String? datetime_create;
  final int id_enterprise;
  final int id_package;
  final String? package;
  final int id_local_view;
  final String? local_view;
  final int event_code;
  final int tenant_id;
  final int status;
  final String? datetime_status;

  EventApi({
    this.id = 0,
    this.id_client = 0,
    this.date_event,
    this.week_day,
    this.hour_event,
    this.hour_end,
    this.birthday_person_one,
    this.age_birthday_person_one = 0,
    this.birthday_person_two,
    this.age_birthday_person_two = 0,
    this.beer = 0,
    this.beer_brand,
    this.cake,
    this.filling,
    this.candy,
    this.broth,
    this.cake_with_ice_cream = 0,
    this.theme,
    this.image_theme,
    this.color_balloons,
    this.arc_balloons_type = 0,
    this.music,
    this.theme_description,
    this.guests = 0,
    this.courtesy = 0,
    this.signalOne = 0.0,
    this.signal_payment,
    this.missing_payment = 0.0,
    this.amount = 0.0,
    this.father_name,
    this.mother_name,
    this.value_package = 0.0,
    this.total = 0.0,
    this.id_user_create = 0,
    this.best_day = 0,
    this.datetime_create,
    this.id_enterprise = 0,
    this.id_package = 0,
    this.package,
    this.id_local_view = 0,
    this.local_view,
    this.event_code = 0,
    this.tenant_id = 0,
    this.status = 0,
    this.datetime_status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_client': id_client,
      'date_event': date_event,
      'week_day': week_day,
      'hour_event': hour_event,
      'hour_end': hour_end,
      'birthday_person_one': birthday_person_one,
      'age_birthday_person_one': age_birthday_person_one,
      'birthday_person_two': birthday_person_two,
      'age_birthday_person_two': age_birthday_person_two,
      'beer': beer,
      'beer_brand': beer_brand,
      'cake': cake,
      'filling': filling,
      'candy': candy,
      'broth': broth,
      'cake_with_ice_cream': cake_with_ice_cream,
      'theme': theme,
      'image_theme': image_theme,
      'color_balloons': color_balloons,
      'arc_balloons_type': arc_balloons_type,
      'music': music,
      'theme_description': theme_description,
      'guests': guests,
      'courtesy': courtesy,
      'signalOne': signalOne,
      'signal_payment': signal_payment,
      'missing_payment': missing_payment,
      'amount': amount,
      'father_name': father_name,
      'mother_name': mother_name,
      'value_package': value_package,
      'total': total,
      'id_user_create': id_user_create,
      'best_day': best_day,
      'datetime_create': datetime_create,
      'id_enterprise': id_enterprise,
      'id_package': id_package,
      'package': package,
      'id_local_view': id_local_view,
      'local_view': local_view,
      'event_code': event_code,
      'tenant_id': tenant_id,
      'status': status,
      'datetime_status': datetime_status,
    };
  }

  factory EventApi.fromJson(Map<String, dynamic> json) {
    return EventApi(
      id: json['id'] ?? 0,
      id_client: json['id_client'] ?? 0,
      date_event: json['date_event'],
      week_day: json['week_day'],
      hour_event: json['hour_event'],
      hour_end: json['hour_end'],
      birthday_person_one: json['birthday_person_one'],
      age_birthday_person_one: json['age_birthday_person_one'] ?? 0,
      birthday_person_two: json['birthday_person_two'],
      age_birthday_person_two: json['age_birthday_person_two'] ?? 0,
      beer: json['beer'] ?? 0,
      beer_brand: json['beer_brand'],
      cake: json['cake'],
      filling: json['filling'],
      candy: json['candy'],
      broth: json['broth'],
      cake_with_ice_cream: json['cake_with_ice_cream'] ?? 0,
      theme: json['theme'],
      image_theme: json['image_theme'],
      color_balloons: json['color_balloons'],
      arc_balloons_type: json['arc_balloons_type'] ?? 0,
      music: json['music'],
      theme_description: json['theme_description'],
      guests: json['guests'] ?? 0,
      courtesy: json['courtesy'] ?? 0,
      signalOne: (json['signalOne'] ?? 0).toDouble(),
      signal_payment: json['signal_payment'],
      missing_payment: (json['missing_payment'] ?? 0).toDouble(),
      amount: (json['amount'] ?? 0).toDouble(),
      father_name: json['father_name'],
      mother_name: json['mother_name'],
      value_package: (json['value_package'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      id_user_create: json['id_user_create'] ?? 0,
      best_day: json['best_day'] ?? 0,
      datetime_create: json['datetime_create'],
      id_enterprise: json['id_enterprise'] ?? 0,
      id_package: json['id_package'] ?? 0,
      package: json['package'],
      id_local_view: json['id_local_view'] ?? 0,
      local_view: json['local_view'],
      event_code: json['event_code'] ?? 0,
      tenant_id: json['tenant_id'] ?? 0,
      status: json['status'] ?? 0,
      datetime_status: json['datetime_status'],
    );
  }
}

// Modelo para User (novo formato) da API
class UserApi {
  final int id;
  final String? usuarioLogin;
  final String? chaveDeAcesso;
  final String? lastName;
  final String? address;
  final String? firstName;
  final String? city;
  final String? cpf;
  final String? born;
  final String? image;
  final String? dooName;
  final String? email;
  final String? contact;
  final String? whatsapp;
  final String? instagram;
  final String? facebook;
  final String? linkedin;
  final int userType;
  final int accountType;
  final int userStatus;
  final String? dateTimeStatus;
  final int status;
  final int id_enterprise;
  final String? cep;
  final String? neighborhood;
  final int tenant_id;

  UserApi({
    this.id = 0,
    this.usuarioLogin,
    this.chaveDeAcesso,
    this.lastName,
    this.address,
    this.firstName,
    this.city,
    this.cpf,
    this.born,
    this.image,
    this.dooName,
    this.email,
    this.contact,
    this.whatsapp,
    this.instagram,
    this.facebook,
    this.linkedin,
    this.userType = 0,
    this.accountType = 0,
    this.userStatus = 0,
    this.dateTimeStatus,
    this.status = 0,
    this.id_enterprise = 0,
    this.cep,
    this.neighborhood,
    this.tenant_id = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuarioLogin': usuarioLogin,
      'chaveDeAcesso': chaveDeAcesso,
      'lastName': lastName,
      'address': address,
      'firstName': firstName,
      'city': city,
      'cpf': cpf,
      'born': born,
      'image': image,
      'dooName': dooName,
      'email': email,
      'contact': contact,
      'whatsapp': whatsapp,
      'instagram': instagram,
      'facebook': facebook,
      'linkedin': linkedin,
      'userType': userType,
      'accountType': accountType,
      'userStatus': userStatus,
      'dateTimeStatus': dateTimeStatus,
      'status': status,
      'id_enterprise': id_enterprise,
      'cep': cep,
      'neighborhood': neighborhood,
      'tenant_id': tenant_id,
    };
  }

  factory UserApi.fromJson(Map<String, dynamic> json) {
    return UserApi(
      id: json['id'] ?? 0,
      usuarioLogin: json['usuarioLogin'],
      chaveDeAcesso: json['chaveDeAcesso'],
      lastName: json['lastName'],
      address: json['address'],
      firstName: json['firstName'],
      city: json['city'],
      cpf: json['cpf'],
      born: json['born'],
      image: json['image'],
      dooName: json['dooName'],
      email: json['email'],
      contact: json['contact'],
      whatsapp: json['whatsapp'],
      instagram: json['instagram'],
      facebook: json['facebook'],
      linkedin: json['linkedin'],
      userType: json['userType'] ?? 0,
      accountType: json['accountType'] ?? 0,
      userStatus: json['userStatus'] ?? 0,
      dateTimeStatus: json['dateTimeStatus'],
      status: json['status'] ?? 0,
      id_enterprise: json['id_enterprise'] ?? 0,
      cep: json['cep'],
      neighborhood: json['neighborhood'],
      tenant_id: json['tenant_id'] ?? 0,
    );
  }

  // Getter para nome completo
  String get nomeCompleto {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    }
    return usuarioLogin ?? email ?? '';
  }
}

// Modelo para Transaction da API (novo formato)
class TransactionApi {
  final int id;
  final int id_input_type;
  final int id_sub_ibput_type;
  final int id_output_type;
  final int id_sub_output_type;
  final String? description;
  final String? title;
  final int id_user_created;
  final String? datetime_created;
  final int id_user_status;
  final String? datetime_status;
  final int status;
  final int id_enterprise;
  final double value;
  final int tenant_id;

  TransactionApi({
    this.id = 0,
    this.id_input_type = 0,
    this.id_sub_ibput_type = 0,
    this.id_output_type = 0,
    this.id_sub_output_type = 0,
    this.description,
    this.title,
    this.id_user_created = 0,
    this.datetime_created,
    this.id_user_status = 0,
    this.datetime_status,
    this.status = 0,
    this.id_enterprise = 0,
    this.value = 0.0,
    this.tenant_id = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_input_type': id_input_type,
      'id_sub_ibput_type': id_sub_ibput_type,
      'id_output_type': id_output_type,
      'id_sub_output_type': id_sub_output_type,
      'description': description,
      'title': title,
      'id_user_created': id_user_created,
      'datetime_created': datetime_created,
      'id_user_status': id_user_status,
      'datetime_status': datetime_status,
      'status': status,
      'id_enterprise': id_enterprise,
      'value': value,
      'tenant_id': tenant_id,
    };
  }

  factory TransactionApi.fromJson(Map<String, dynamic> json) {
    return TransactionApi(
      id: json['id'] ?? 0,
      id_input_type: json['id_input_type'] ?? 0,
      id_sub_ibput_type: json['id_sub_ibput_type'] ?? 0,
      id_output_type: json['id_output_type'] ?? 0,
      id_sub_output_type: json['id_sub_output_type'] ?? 0,
      description: json['description'],
      title: json['title'],
      id_user_created: json['id_user_created'] ?? 0,
      datetime_created: json['datetime_created'],
      id_user_status: json['id_user_status'] ?? 0,
      datetime_status: json['datetime_status'],
      status: json['status'] ?? 0,
      id_enterprise: json['id_enterprise'] ?? 0,
      value: (json['value'] ?? 0).toDouble(),
      tenant_id: json['tenant_id'] ?? 0,
    );
  }
}

// Modelo para PaymentEvent da API
class PaymentEventApi {
  final int id;
  final int id_event;
  final String? date_vigency;
  final String? date_payment;
  final String? payment_method;
  final double? value;
  final String? description;
  final int id_user_created;
  final String? datetime_created;
  final int id_enterprise;
  final int status;
  final String? datetime_status;
  final int id_user_status;
  final int tenant_id;
  
  // Campos legados para compatibilidade
  final String? whatsapp;
  final String? firstName;
  final String? date_event;
  final String? birthday_person_one;
  final int age_birthday_person_one;
  final String? reference_date;
  final String? last_payment;
  final int paymentDelay;
  final int id_user_create;
  final String? datetime_create;

  PaymentEventApi({
    this.id = 0,
    this.id_event = 0,
    this.date_vigency,
    this.date_payment,
    this.payment_method,
    this.value,
    this.description,
    this.id_user_created = 0,
    this.datetime_created,
    this.id_enterprise = 0,
    this.status = 0,
    this.datetime_status,
    this.id_user_status = 0,
    this.tenant_id = 0,
    // Campos legados
    this.whatsapp,
    this.firstName,
    this.date_event,
    this.birthday_person_one,
    this.age_birthday_person_one = 0,
    this.reference_date,
    this.last_payment,
    this.paymentDelay = 0,
    this.id_user_create = 0,
    this.datetime_create,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_event': id_event,
      'date_vigency': date_vigency,
      'date_payment': date_payment,
      'payment_method': payment_method,
      'value': value,
      'description': description,
      'id_user_created': id_user_created,
      'datetime_created': datetime_created,
      'id_enterprise': id_enterprise,
      'status': status,
      'datetime_status': datetime_status,
      'id_user_status': id_user_status,
      'tenant_id': tenant_id,
    };
  }

  factory PaymentEventApi.fromJson(Map<String, dynamic> json) {
    // Converter campos de data que podem vir como int ou String
    String? convertDateField(dynamic value) {
      if (value == null) return null;
      if (value is int) return value.toString();
      if (value is String) return value;
      return value.toString();
    }
    
    return PaymentEventApi(
      id: json['id'] ?? 0,
      id_event: json['id_event'] ?? 0,
      date_vigency: convertDateField(json['date_vigency']),
      date_payment: convertDateField(json['date_payment']),
      payment_method: json['payment_method']?.toString(),
      value: json['value'] != null ? (json['value'] as num).toDouble() : null,
      description: json['description']?.toString(),
      id_user_created: json['id_user_created'] ?? json['id_user_create'] ?? 0,
      datetime_created: convertDateField(json['datetime_created'] ?? json['datetime_create']),
      id_enterprise: json['id_enterprise'] ?? 0,
      status: json['status'] is int ? json['status'] : (json['status'] is String ? int.tryParse(json['status']) ?? 0 : 0),
      datetime_status: convertDateField(json['datetime_status']),
      id_user_status: json['id_user_status'] ?? 0,
      tenant_id: json['tenant_id'] ?? 0,
      // Campos legados para compatibilidade
      whatsapp: json['whatsapp']?.toString(),
      firstName: json['firstName'] ?? json['description']?.toString(),
      date_event: convertDateField(json['date_event'] ?? json['date_vigency']),
      birthday_person_one: json['birthday_person_one']?.toString(),
      age_birthday_person_one: json['age_birthday_person_one'] ?? 0,
      reference_date: convertDateField(json['reference_date'] ?? json['date_vigency']),
      last_payment: convertDateField(json['last_payment'] ?? json['date_payment']),
      paymentDelay: json['paymentDelay'] ?? 0,
      id_user_create: json['id_user_create'] ?? json['id_user_created'] ?? 0,
      datetime_create: convertDateField(json['datetime_create'] ?? json['datetime_created']),
    );
  }
}

// Modelo para Extra da API
class ExtraApi {
  final int id;
  final String name;
  final String? description;
  final double value;
  final int id_user_created;
  final String? datetime_created;
  final int id_enterprise;
  final bool selected;
  final int tenant_id;

  ExtraApi({
    this.id = 0,
    required this.name,
    this.description,
    this.value = 0.0,
    this.id_user_created = 0,
    this.datetime_created,
    this.id_enterprise = 0,
    this.selected = false,
    this.tenant_id = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'value': value,
      'id_user_created': id_user_created,
      'datetime_created': datetime_created,
      'id_enterprise': id_enterprise,
      'selected': selected,
      'tenant_id': tenant_id,
    };
  }

  factory ExtraApi.fromJson(Map<String, dynamic> json) {
    return ExtraApi(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      value: (json['value'] ?? 0).toDouble(),
      id_user_created: json['id_user_created'] ?? 0,
      datetime_created: json['datetime_created'],
      id_enterprise: json['id_enterprise'] ?? 0,
      selected: json['selected'] ?? false,
      tenant_id: json['tenant_id'] ?? 0,
    );
  }
}

// Modelo para Tenant da API
class TenantApi {
  final int id;
  final String? whatsapp;
  // Adicionar outros campos conforme necessário
  
  TenantApi({
    this.id = 0,
    this.whatsapp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'whatsapp': whatsapp,
    };
  }

  factory TenantApi.fromJson(Map<String, dynamic> json) {
    return TenantApi(
      id: json['id'] ?? 0,
      whatsapp: json['whatsapp'],
    );
  }
}

// Modelo para ExtraEvent da API
class ExtraEventApi {
  final int id;
  final int id_event;
  final int id_extra;
  final int id_user_created;
  final String? datetime_created;
  final int id_enterprise;
  final int tenant_id;

  ExtraEventApi({
    this.id = 0,
    this.id_event = 0,
    this.id_extra = 0,
    this.id_user_created = 0,
    this.datetime_created,
    this.id_enterprise = 0,
    this.tenant_id = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_event': id_event,
      'id_extra': id_extra,
      'id_user_created': id_user_created,
      'datetime_created': datetime_created,
      'id_enterprise': id_enterprise,
      'tenant_id': tenant_id,
    };
  }

  factory ExtraEventApi.fromJson(Map<String, dynamic> json) {
    return ExtraEventApi(
      id: json['id'] ?? 0,
      id_event: json['id_event'] ?? 0,
      id_extra: json['id_extra'] ?? 0,
      id_user_created: json['id_user_created'] ?? 0,
      datetime_created: json['datetime_created'],
      id_enterprise: json['id_enterprise'] ?? 0,
      tenant_id: json['tenant_id'] ?? 0,
    );
  }
}