import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/membership_service.dart' show MembershipAccessConfig, MembershipPlan, MembershipService;
import '../constants/app_colors.dart';
import 'membership_access_settings.dart';

const _billingLabels = {
  'monthly': 'Mensal',
  'quarterly': 'Trimestral',
  'yearly': 'Anual',
};

/// Gerenciador de planos de mensalidade (admin) + configurações de acesso.
class MembershipPlansManager extends StatefulWidget {
  final String fanClubId;

  const MembershipPlansManager({super.key, required this.fanClubId});

  @override
  State<MembershipPlansManager> createState() => _MembershipPlansManagerState();
}

class _MembershipPlansManagerState extends State<MembershipPlansManager> {
  List<MembershipPlan> _plans = [];
  bool _loading = true;
  bool _canReceivePayments = false;
  bool _requiresMembership = false;
  MembershipPlan? _editingPlan;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _benefitsController = TextEditingController();
  String _billingPeriod = 'monthly';
  bool _isActive = true;
  bool _isDefault = false;
  bool _accessExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _benefitsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        MembershipService.getAllPlans(widget.fanClubId),
        MembershipService.canReceivePayments(widget.fanClubId),
        MembershipService.getAccessSettings(widget.fanClubId),
      ]);
      if (mounted) {
        setState(() {
          _plans = results[0] as List<MembershipPlan>;
          _canReceivePayments = results[1] as bool;
          _requiresMembership = (results[2] as (bool, MembershipAccessConfig)).$1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _openDialog([MembershipPlan? plan]) {
    _editingPlan = plan;
    if (plan != null) {
      _nameController.text = plan.name;
      _descriptionController.text = plan.description ?? '';
      _priceController.text = plan.price.toStringAsFixed(2);
      _benefitsController.text = plan.benefits.join('\n');
      _billingPeriod = plan.billingPeriod;
      _isActive = plan.isActive;
      _isDefault = plan.isDefault;
    } else {
      _nameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _benefitsController.clear();
      _billingPeriod = 'monthly';
      _isActive = true;
      _isDefault = false;
    }
    _showPlanDialog();
  }

  void _closeDialog() {
    Navigator.of(context).pop();
    _editingPlan = null;
  }

  Future<void> _toggleRequiresMembership(bool value) async {
    try {
      await MembershipService.updateRequiresMembership(widget.fanClubId, value);
      if (mounted) {
        setState(() => _requiresMembership = value);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value ? 'Mensalidade habilitada' : 'Mensalidade desabilitada'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Informe um valor válido'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final benefits = _benefitsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    try {
      await MembershipService.savePlan(
        fanClubId: widget.fanClubId,
        planId: _editingPlan?.id,
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        price: price,
        billingPeriod: _billingPeriod,
        benefits: benefits,
        isActive: _isActive,
        isDefault: _isDefault,
      );
      if (mounted) {
        _closeDialog();
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_editingPlan != null ? 'Plano atualizado!' : 'Plano criado!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _toggleActive(MembershipPlan plan) async {
    try {
      await MembershipService.togglePlanActive(plan.id, !plan.isActive);
      if (mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(plan.isActive ? 'Plano desativado' : 'Plano ativado'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _deletePlan(MembershipPlan plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir plano'),
        content: Text(
          'Tem certeza que deseja excluir o plano "${plan.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await MembershipService.deletePlan(plan.id);
      if (mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Plano excluído!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_canReceivePayments)
              Card(
                color: AppColors.error.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Planos indisponíveis',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Configure a chave PIX nas configurações da torcida para habilitar os planos.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Planos de Mensalidade',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Configure os planos de associação da torcida',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _canReceivePayments ? () => _openDialog() : null,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Novo plano'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: SwitchListTile(
                title: const Text('Exigir Mensalidade'),
                subtitle: Text(
                  'Novos membros precisarão escolher um plano ao se cadastrar',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                value: _requiresMembership,
                onChanged: _toggleRequiresMembership,
                activeColor: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            ExpansionTile(
              initiallyExpanded: _accessExpanded,
              onExpansionChanged: (v) => setState(() => _accessExpanded = v),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Row(
                children: [
                  Icon(Icons.settings, color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  const Text(
                    'Configurações de Acesso',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              children: [
                MembershipAccessSettings(
                  fanClubId: widget.fanClubId,
                  requiresMembership: _requiresMembership,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_plans.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.credit_card, size: 56, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenhum plano cadastrado',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crie planos de mensalidade para sua torcida',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount =
                      constraints.maxWidth > 600 ? 3 : (constraints.maxWidth > 400 ? 2 : 1);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _plans.length,
                    itemBuilder: (_, i) => _buildPlanCard(_plans[i]),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(MembershipPlan plan) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: plan.isDefault ? AppColors.primary : Colors.transparent,
          width: plan.isDefault ? 2 : 0,
        ),
      ),
      child: Opacity(
        opacity: plan.isActive ? 1 : 0.6,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (plan.isDefault)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Recomendado',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: plan.isActive
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.textSecondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      plan.isActive ? 'Ativo' : 'Inativo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: plan.isActive ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (plan.description != null && plan.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  plan.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'R\$ ${plan.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/${(_billingLabels[plan.billingPeriod] ?? plan.billingPeriod).toLowerCase()}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (plan.benefits.isNotEmpty) ...[
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: plan.benefits.length.clamp(0, 4),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check, size: 16, color: AppColors.success),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plan.benefits[i],
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _openDialog(plan),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar',
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleActive(plan),
                    icon: Icon(
                      plan.isActive ? Icons.toggle_on : Icons.toggle_off,
                      size: 32,
                    ),
                    tooltip: plan.isActive ? 'Desativar' : 'Ativar',
                    style: IconButton.styleFrom(
                      foregroundColor: plan.isActive ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deletePlan(plan),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Excluir',
                    style: IconButton.styleFrom(foregroundColor: AppColors.error),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlanDialog() {
    String billingPeriod = _billingPeriod;
    bool isActive = _isActive;
    bool isDefault = _isDefault;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _editingPlan != null ? 'Editar Plano' : 'Novo Plano',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do plano *',
                          hintText: 'Ex: Plano Básico, Plano Torcedor',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final useColumn = constraints.maxWidth < 360;
                          if (useColumn) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _priceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Valor (R\$) *',
                                    hintText: '29.90',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                                  ],
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Obrigatório';
                                    final n = double.tryParse(v.replaceAll(',', '.'));
                                    if (n == null || n <= 0) return 'Valor inválido';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: billingPeriod,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Período',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _billingLabels.entries
                                      .map((e) => DropdownMenuItem(
                                            value: e.key,
                                            child: Text(
                                              e.value,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    billingPeriod = v ?? 'monthly';
                                    _billingPeriod = billingPeriod;
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _priceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Valor (R\$) *',
                                    hintText: '29.90',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                                  ],
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Obrigatório';
                                    final n = double.tryParse(v.replaceAll(',', '.'));
                                    if (n == null || n <= 0) return 'Valor inválido';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: billingPeriod,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Período',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _billingLabels.entries
                                      .map((e) => DropdownMenuItem(
                                            value: e.key,
                                            child: Text(
                                              e.value,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    billingPeriod = v ?? 'monthly';
                                    _billingPeriod = billingPeriod;
                                    setModalState(() {});
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _benefitsController,
                        decoration: const InputDecoration(
                          labelText: 'Benefícios (um por linha)',
                          hintText: 'Desconto em produtos\nAcesso antecipado',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Plano ativo'),
                        value: isActive,
                        onChanged: (v) {
                          isActive = v;
                          _isActive = isActive;
                          setModalState(() {});
                        },
                        activeColor: AppColors.primary,
                      ),
                      SwitchListTile(
                        title: const Text('Plano padrão (recomendado)'),
                        value: isDefault,
                        onChanged: (v) {
                          isDefault = v;
                          _isDefault = isDefault;
                          setModalState(() {});
                        },
                        activeColor: AppColors.primary,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _editingPlan = null;
                              },
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                _billingPeriod = billingPeriod;
                                _isActive = isActive;
                                _isDefault = isDefault;
                                await _savePlan();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.textLight,
                              ),
                              child: Text(_editingPlan != null ? 'Salvar' : 'Criar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
