import React, { useState, useEffect, useCallback } from 'react';
import { api } from '../apiClient';
import {
  SlidersHorizontal, Plus, Trash2, Edit2, X, CheckCircle2,
  Loader2, Globe, Tag, ChevronDown, Search, AlertCircle, Save
} from 'lucide-react';

const SCOPE_OPTIONS = [
  { value: 'global',      label: 'Global (All Products)', color: 'emerald' },
  { value: 'category',    label: 'Category Global', color: 'blue' },
  { value: 'subcategory', label: 'Subcategory', color: 'violet' },
];

const UI_TYPE_OPTIONS = [
  { value: 'multiselect',    label: 'Chip Multiselect' },
  { value: 'chip-selection', label: 'Chip Single-select' },
  { value: 'single-select',  label: 'Dropdown Single-select' },
  { value: 'range',          label: 'Range Slider' },
  { value: 'boolean',        label: 'Yes / No Switch' },
  { value: 'rating',         label: 'Star Rating' },
  { value: 'text',           label: 'Plain Text Input' },
];

const DATA_TYPE_OPTIONS = [
  { value: 'string',  label: 'String (text)' },
  { value: 'number',  label: 'Number' },
  { value: 'boolean', label: 'Boolean' },
];

const scopeBadge = (scope) => {
  const map = {
    global:      'bg-emerald-50 text-emerald-700 border-emerald-200',
    category:    'bg-blue-50 text-blue-700 border-blue-200',
    subcategory: 'bg-violet-50 text-violet-700 border-violet-200',
  };
  return map[scope] || 'bg-slate-50 text-slate-600 border-slate-200';
};

const uiTypeIcon = (type) => {
  const map = {
    multiselect:    '⬜⬜⬜',
    'chip-selection': '🔵',
    'single-select': '◉',
    range:          '⟷',
    boolean:        '⏻',
    rating:         '★',
  };
  return map[type] || '—';
};

const EMPTY_FILTER = {
  key: '',
  label: '',
  scope: 'category',
  category_id: '',
  subcategory_id: '',
  ui_type: 'multiselect',
  data_type: 'string',
  options: '',
  sort_order: 0,
  is_required: false,
  show_in_mobile_filters: true,
  is_searchable: false,
  default_value: '',
};

const optionsNeedInput = (ui_type) =>
  ['multiselect', 'chip-selection', 'single-select'].includes(ui_type);

const FilterManager = () => {
  const [filters, setFilters]         = useState([]);
  const [categories, setCategories]   = useState([]);
  const [loading, setLoading]         = useState(true);
  const [showModal, setShowModal]     = useState(false);
  const [editingFilter, setEditingFilter] = useState(null);
  const [formData, setFormData]       = useState(EMPTY_FILTER);
  const [saving, setSaving]           = useState(false);
  const [success, setSuccess]         = useState('');
  const [error, setError]             = useState('');
  const [search, setSearch]           = useState('');
  const [scopeFilter, setScopeFilter] = useState('all');
  const [deleting, setDeleting]       = useState(null);
  // Values this filter's key already holds across the catalog, so options can be
  // filled from reality rather than guessed.
  const [discovered, setDiscovered]   = useState(null);
  const [discovering, setDiscovering] = useState(false);
  // products_in_scope vs products_with_value, keyed by filter id.
  const [coverage, setCoverage]       = useState({});

  // Derived: subcategories visible for selected category_id in form
  const subCategories = categories.filter(
    (c) => c.parent_id && String(c.parent_id) === String(formData.category_id)
  );
  const mainCategories = categories.filter((c) => !c.parent_id);

  const fetchAll = useCallback(async () => {
    setLoading(true);
    const [{ filters: filterData }, { categories: catData }] = await Promise.all([
      api.get('/filters?all=true'),
      api.get('/categories?all=true'),
    ]);
    setFilters((filterData || []).slice().sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0)));
    setCategories((catData || []).slice().sort((a, b) => a.name.localeCompare(b.name)));
    setLoading(false);

    // Non-blocking: coverage is a diagnostic, so a failure here shouldn't stop
    // the manager from rendering.
    try {
      const { coverage: rows } = await api.get('/filters/coverage');
      setCoverage(Object.fromEntries((rows || []).map((r) => [r.id, r])));
    } catch {
      setCoverage({});
    }
  }, []);

  /// Reads the values products already store under this key so the option list
  /// can't drift from the data it's meant to match.
  const discoverOptions = async () => {
    const key = formData.key.trim();
    if (!key) return;
    setDiscovering(true);
    try {
      const params = new URLSearchParams({ key });
      const scopeCategory = formData.subcategory_id || formData.category_id;
      if (scopeCategory) params.set('category_id', scopeCategory);

      const { values } = await api.get(`/products/attribute-values?${params.toString()}`);
      setDiscovered(values || []);
      if ((values || []).length) {
        setFormData((prev) => ({ ...prev, options: values.map((v) => v.value).join(', ') }));
      }
    } catch (e) {
      setDiscovered([]);
      setError(e.message || 'Could not read catalog values');
    }
    setDiscovering(false);
  };

  useEffect(() => { fetchAll(); }, [fetchAll]);

  const autoKey = (label) =>
    label.toLowerCase().trim().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');

  const openAdd = () => {
    setEditingFilter(null);
    setFormData(EMPTY_FILTER);
    setDiscovered(null);
    setError('');
    setShowModal(true);
  };

  const openEdit = (f) => {
    setEditingFilter(f);
    setFormData({
      key:                    f.key,
      label:                  f.label,
      scope:                  f.scope,
      category_id:            f.category_id ? String(f.category_id) : '',
      subcategory_id:         f.subcategory_id ? String(f.subcategory_id) : '',
      ui_type:                f.ui_type,
      data_type:              f.data_type,
      options:                Array.isArray(f.options) ? f.options.join(', ') : '',
      sort_order:             f.sort_order ?? 0,
      is_required:            f.is_required ?? false,
      show_in_mobile_filters: f.show_in_mobile_filters ?? true,
      is_searchable:          f.is_searchable ?? false,
      default_value:          f.default_value ?? '',
    });
    setDiscovered(null);
    setError('');
    setShowModal(true);
  };

  const handleLabelChange = (e) => {
    const label = e.target.value;
    setFormData((prev) => ({
      ...prev,
      label,
      // Auto-generate key only if user hasn't manually edited it
      key: editingFilter ? prev.key : autoKey(label),
    }));
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!formData.key.trim() || !formData.label.trim()) {
      setError('Key and Label are required.');
      return;
    }
    if (formData.scope === 'category' && !formData.category_id) {
      setError('Please select a Category for inherited category filters.');
      return;
    }
    if (formData.scope === 'subcategory' && !formData.subcategory_id) {
      setError('Please select a Subcategory for subcategory-scoped filters.');
      return;
    }

    setSaving(true);
    setError('');

    const parsedOptions = optionsNeedInput(formData.ui_type)
      ? formData.options.split(',').map((o) => {
          const t = o.trim();
          return formData.data_type === 'number' ? parseFloat(t) || t : t;
        }).filter((o) => o !== '' && !Number.isNaN(o))
      : [];

    const payload = {
      key:                    formData.key.trim(),
      label:                  formData.label.trim(),
      scope:                  formData.scope,
      category_id:            formData.category_id || null,
      subcategory_id:         formData.scope === 'subcategory' && formData.subcategory_id ? formData.subcategory_id : null,
      ui_type:                formData.ui_type,
      data_type:              formData.data_type,
      options:                parsedOptions,
      sort_order:             parseInt(formData.sort_order) || 0,
      is_required:            formData.is_required,
      show_in_mobile_filters: formData.show_in_mobile_filters,
      is_searchable:          formData.is_searchable,
      default_value:          formData.default_value.trim() || null,
    };

    try {
      if (editingFilter) {
        await api.patch(`/filters/${editingFilter.id}`, payload);
        setSuccess('Filter updated successfully!');
      } else {
        await api.post('/filters', payload);
        setSuccess('Filter created successfully!');
      }
      setShowModal(false);
      fetchAll();
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError(err.message || 'Save failed');
    }
    setSaving(false);
  };

  const handleDelete = async (filterId) => {
    if (!window.confirm('Delete this filter? Products with this attribute key will retain values, but new products won\'t see this filter.')) return;
    setDeleting(filterId);
    await api.delete(`/filters/${filterId}`);
    fetchAll();
    setDeleting(null);
    setSuccess('Filter deleted.');
    setTimeout(() => setSuccess(''), 3000);
  };

  const toggleActive = async (f) => {
    await api.patch(`/filters/${f.id}`, { is_active: !f.is_active });
    fetchAll();
  };

  const getCategoryName = (id) => categories.find((c) => String(c.id) === String(id))?.name || '—';

  const displayed = filters.filter((f) => {
    const matchScope = scopeFilter === 'all' || f.scope === scopeFilter;
    const matchSearch = !search
      || f.key.toLowerCase().includes(search.toLowerCase())
      || f.label.toLowerCase().includes(search.toLowerCase());
    return matchScope && matchSearch;
  });

  return (
    <div className="w-full space-y-8 font-sans animate-in fade-in duration-500">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-100">
        <div>
          <h2 className="text-xl font-bold text-slate-900 tracking-tight flex items-center gap-2">
            <SlidersHorizontal size={20} className="text-violet-600" />
            Filter Manager
          </h2>
          <p className="text-slate-500 text-sm font-normal mt-0.5">
            Define category-owned and subcategory filters rendered dynamically in the mobile app.
          </p>
        </div>
        <button
          onClick={openAdd}
          className="flex items-center gap-2 bg-violet-600 hover:bg-violet-700 text-white px-5 py-2.5 rounded-xl font-semibold transition-all shadow-md shadow-violet-600/10 text-sm cursor-pointer flex-shrink-0"
        >
          <Plus size={16} />
          Add Filter
        </button>
      </div>

      {/* Success / Error banners */}
      {success && (
        <div className="flex items-center gap-2 text-emerald-600 bg-emerald-50 p-3.5 rounded-xl border border-emerald-100 text-sm font-medium animate-in slide-in-from-top-2 duration-200">
          <CheckCircle2 size={16} /> <span>{success}</span>
        </div>
      )}

      {/* Controls: Search + Scope tabs */}
      <div className="flex flex-col sm:flex-row gap-3 items-start sm:items-center">
        <div className="relative flex-1 max-w-xs">
          <Search size={14} className="absolute left-3 top-3 text-slate-400" />
          <input
            type="text"
            placeholder="Search by key or label..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-700 focus:outline-none focus:border-violet-500 focus:ring-2 focus:ring-violet-500/10 text-xs transition-all"
          />
        </div>
        <div className="flex gap-1 bg-slate-100 p-1 rounded-xl">
          {['all', 'global', 'category', 'subcategory'].map((s) => (
            <button
              key={s}
              onClick={() => setScopeFilter(s)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer capitalize ${
                scopeFilter === s
                  ? 'bg-white text-slate-800 shadow-sm'
                  : 'text-slate-500 hover:text-slate-700'
              }`}
            >
              {s}
            </button>
          ))}
        </div>
        <span className="text-xs text-slate-400 font-medium ml-auto">
          {displayed.length} filter{displayed.length !== 1 ? 's' : ''}
        </span>
      </div>

      {/* Filters Table */}
      {loading ? (
        <div className="py-20 flex flex-col items-center gap-3 text-slate-400">
          <Loader2 className="animate-spin text-violet-600" size={28} />
          <p className="text-sm">Loading filters...</p>
        </div>
      ) : displayed.length === 0 ? (
        <div className="py-16 flex flex-col items-center gap-3 text-center border border-dashed border-slate-200 rounded-2xl bg-slate-50/50">
          <SlidersHorizontal size={32} className="text-slate-300" />
          <p className="text-sm font-semibold text-slate-400">No filters found</p>
          <p className="text-xs text-slate-400">Click "Add Filter" to create your first dynamic filter</p>
        </div>
      ) : (
        <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/60">
                <th className="text-left text-[10px] font-bold text-slate-400 uppercase tracking-wider px-5 py-3">Label / Key</th>
                <th className="text-left text-[10px] font-bold text-slate-400 uppercase tracking-wider px-4 py-3">Scope</th>
                <th className="text-left text-[10px] font-bold text-slate-400 uppercase tracking-wider px-4 py-3 hidden md:table-cell">Category / Subcategory</th>
                <th className="text-left text-[10px] font-bold text-slate-400 uppercase tracking-wider px-4 py-3 hidden lg:table-cell">UI Type</th>
                <th className="text-left text-[10px] font-bold text-slate-400 uppercase tracking-wider px-4 py-3 hidden lg:table-cell">Options</th>
                <th className="text-left text-[10px] font-bold text-slate-400 uppercase tracking-wider px-4 py-3 hidden xl:table-cell">Flags</th>
                <th className="text-left text-[10px] font-bold text-slate-400 uppercase tracking-wider px-4 py-3">Active</th>
                <th className="text-right text-[10px] font-bold text-slate-400 uppercase tracking-wider px-5 py-3">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {displayed.map((f) => (
                <tr key={f.id} className={`hover:bg-slate-50/50 transition-colors ${!f.is_active ? 'opacity-50' : ''}`}>
                  <td className="px-5 py-4">
                    <span className="text-slate-900 font-semibold text-sm block">{f.label}</span>
                    <span className="text-slate-400 text-xs font-mono mt-0.5 block">{f.key}</span>
                    {/* The usual failure mode is a filter that exists but no product
                        populates — it shows up in the app and matches nothing. */}
                    {coverage[f.id] && (
                      coverage[f.id].products_with_value === 0 ? (
                        <span className="inline-flex items-center gap-1 mt-1 text-[10px] font-bold text-amber-600">
                          <AlertCircle size={10} />
                          No products use this yet
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1.5 mt-1 text-[10px] font-medium text-slate-400">
                          <span className="text-emerald-600 font-bold">
                            {coverage[f.id].products_with_value}/{coverage[f.id].products_in_scope}
                          </span>
                          products set
                          {coverage[f.id].missing_options?.length > 0 && (
                            <span
                              className="text-amber-600 font-bold"
                              title={`Values on products but missing from this filter's options: ${coverage[f.id].missing_options.join(', ')}`}
                            >
                              · {coverage[f.id].missing_options.length} unlisted
                            </span>
                          )}
                        </span>
                      )
                    )}
                  </td>
                  <td className="px-4 py-4">
                    <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-bold border capitalize ${scopeBadge(f.scope)}`}>
                      {f.scope === 'global' && <Globe size={9} />}
                      {f.scope}
                    </span>
                  </td>
                  <td className="px-4 py-4 hidden md:table-cell">
                    <span className="text-slate-600 text-xs">
                      {f.scope === 'global' && <span className="text-slate-400 italic">All categories</span>}
                      {f.scope === 'category' && getCategoryName(f.category_id)}
                      {f.scope === 'subcategory' && (
                        <span>
                          {getCategoryName(f.category_id)}
                          <span className="text-slate-400"> › </span>
                          {getCategoryName(f.subcategory_id)}
                        </span>
                      )}
                    </span>
                  </td>
                  <td className="px-4 py-4 hidden lg:table-cell">
                    <span className="text-slate-600 text-xs capitalize flex items-center gap-1.5">
                      <span className="text-base leading-none">{uiTypeIcon(f.ui_type)}</span>
                      {UI_TYPE_OPTIONS.find(u => u.value === f.ui_type)?.label || f.ui_type}
                    </span>
                  </td>
                  <td className="px-4 py-4 hidden lg:table-cell">
                    {Array.isArray(f.options) && f.options.length > 0 ? (
                      <div className="flex flex-wrap gap-1">
                        {f.options.slice(0, 3).map((opt, i) => (
                          <span key={i} className="bg-slate-100 text-slate-600 px-1.5 py-0.5 rounded text-[10px] font-medium">
                            {String(opt)}
                          </span>
                        ))}
                        {f.options.length > 3 && (
                          <span className="text-slate-400 text-[10px]">+{f.options.length - 3}</span>
                        )}
                      </div>
                    ) : (
                      <span className="text-slate-300 text-xs italic">—</span>
                    )}
                  </td>
                  <td className="px-4 py-4 hidden xl:table-cell">
                    <div className="flex flex-wrap gap-1">
                      {f.show_in_mobile_filters && (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-indigo-50 text-indigo-700 border border-indigo-100" title="Shown in mobile filter drawer">📱 Mobile</span>
                      )}
                      {f.is_required && (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-50 text-rose-700 border border-rose-100" title="Required in Add Product">* Required</span>
                      )}
                      {!f.show_in_mobile_filters && !f.is_required && (
                        <span className="text-slate-300 text-xs italic">—</span>
                      )}
                    </div>
                  </td>
                  <td className="px-4 py-4">
                    <button
                      onClick={() => toggleActive(f)}
                      className={`relative w-9 h-5 rounded-full transition-colors cursor-pointer flex-shrink-0 ${
                        f.is_active ? 'bg-emerald-500' : 'bg-slate-200'
                      }`}
                    >
                      <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${
                        f.is_active ? 'translate-x-4' : 'translate-x-0.5'
                      }`} />
                    </button>
                  </td>
                  <td className="px-5 py-4 text-right">
                    <div className="flex items-center justify-end gap-2">
                      <button
                        onClick={() => openEdit(f)}
                        className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-all cursor-pointer"
                        title="Edit filter"
                      >
                        <Edit2 size={14} />
                      </button>
                      <button
                        onClick={() => handleDelete(f.id)}
                        disabled={deleting === f.id}
                        className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-all cursor-pointer disabled:opacity-50"
                        title="Delete filter"
                      >
                        {deleting === f.id ? <Loader2 size={14} className="animate-spin" /> : <Trash2 size={14} />}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Scope Legend */}
      <div className="flex items-center gap-6 pt-2">
        {SCOPE_OPTIONS.map((s) => (
          <div key={s.value} className="flex items-center gap-1.5 text-xs text-slate-500">
            <span className={`inline-block w-2 h-2 rounded-full bg-${s.color}-500`} />
            <span className="capitalize font-medium">{s.label}</span>
            <span className="text-slate-400">— applies to {
              s.value === 'global' ? 'all categories & subcategories' :
              s.value === 'category' ? 'a single category + its subcategories' :
              'one specific subcategory only'
            }</span>
          </div>
        ))}
      </div>

      {/* ===== Add / Edit Modal ===== */}
      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/30 backdrop-blur-sm animate-in fade-in duration-150">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-xl max-h-[90vh] overflow-y-auto animate-in zoom-in-95 duration-200">
            <div className="flex items-center justify-between px-6 py-5 border-b border-slate-100">
              <div>
                <h3 className="font-bold text-slate-900 text-base">
                  {editingFilter ? 'Edit Filter' : 'Add New Filter'}
                </h3>
                <p className="text-slate-400 text-xs mt-0.5">
                  {editingFilter ? 'Update filter metadata and options.' : 'Define a new filter to appear in the mobile app.'}
                </p>
              </div>
              <button
                onClick={() => setShowModal(false)}
                className="p-2 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-xl transition-all cursor-pointer"
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleSave} className="p-6 space-y-5">
              {error && (
                <div className="flex items-start gap-2 bg-rose-50 border border-rose-100 text-rose-600 p-3.5 rounded-xl text-xs font-medium">
                  <AlertCircle size={14} className="flex-shrink-0 mt-0.5" />
                  <span>{error}</span>
                </div>
              )}

              {/* Label + Key row */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                    Label <span className="text-rose-400">*</span>
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Capacity"
                    value={formData.label}
                    onChange={handleLabelChange}
                    className="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 focus:outline-none focus:border-violet-500 focus:ring-2 focus:ring-violet-500/10 text-sm transition-all placeholder-slate-300"
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                    Filter Key <span className="text-rose-400">*</span>
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. capacity_ml"
                    value={formData.key}
                    onChange={(e) => setFormData({ ...formData, key: e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, '_') })}
                    className="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 font-mono focus:outline-none focus:border-violet-500 focus:ring-2 focus:ring-violet-500/10 text-sm transition-all placeholder-slate-300"
                  />
                  <p className="text-[10px] text-slate-400">Auto-generated from label. Used as the attribute key in products.</p>
                </div>
              </div>

              {/* Scope */}
              <div className="space-y-1.5">
                <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                  Filter Scope <span className="text-rose-400">*</span>
                </label>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                  {SCOPE_OPTIONS.map((s) => (
                    <button
                      key={s.value}
                      type="button"
                      onClick={() => setFormData({ ...formData, scope: s.value, category_id: '', subcategory_id: '' })}
                      className={`px-3 py-2.5 rounded-xl border-2 text-xs font-bold transition-all cursor-pointer capitalize ${
                        formData.scope === s.value
                          ? `border-${s.color}-500 bg-${s.color}-50 text-${s.color}-700`
                          : 'border-slate-200 text-slate-500 hover:border-slate-300'
                      }`}
                    >
                      {s.value === 'global' && <Globe size={11} className="inline mr-1" />}
                      {s.label}
                    </button>
                  ))}
                </div>
                <p className="text-[10px] text-slate-400 pt-0.5">
                  {formData.scope === 'global' && 'Appears for all products regardless of category.'}
                  {formData.scope === 'category' && 'Appears for all products in a specific category.'}
                  {formData.scope === 'subcategory' && 'Appears only for products in a specific subcategory.'}
                </p>
              </div>

              {/* Category Assignment (shown for category + subcategory scope) */}
              {(formData.scope === 'category' || formData.scope === 'subcategory') && (
                <div className="space-y-1.5 animate-in slide-in-from-top-2 duration-200">
                  <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                    Category <span className="text-rose-400">*</span>
                  </label>
                  <div className="relative">
                    <Tag size={14} className="absolute left-3 top-3 text-slate-400" />
                    <select
                      required
                      value={formData.category_id}
                      onChange={(e) => setFormData({ ...formData, category_id: e.target.value, subcategory_id: '' })}
                      className="w-full pl-9 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 focus:outline-none focus:border-violet-500 focus:ring-2 focus:ring-violet-500/10 text-sm appearance-none cursor-pointer transition-all"
                    >
                      <option value="">Select Category</option>
                      {mainCategories.map((c) => (
                        <option key={c.id} value={c.id}>{c.name}</option>
                      ))}
                    </select>
                    <ChevronDown size={14} className="absolute right-3 top-3 text-slate-400 pointer-events-none" />
                  </div>
                </div>
              )}

              {/* Subcategory Assignment (shown only for subcategory scope) */}
              {formData.scope === 'subcategory' && formData.category_id && (
                <div className="space-y-1.5 animate-in slide-in-from-top-2 duration-200">
                  <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                    Subcategory <span className="text-rose-400">*</span>
                  </label>
                  <div className="relative">
                    <Tag size={14} className="absolute left-3 top-3 text-slate-400" />
                    <select
                      required
                      value={formData.subcategory_id}
                      onChange={(e) => setFormData({ ...formData, subcategory_id: e.target.value })}
                      className="w-full pl-9 pr-4 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 focus:outline-none focus:border-violet-500 focus:ring-2 focus:ring-violet-500/10 text-sm appearance-none cursor-pointer transition-all"
                    >
                      <option value="">Select Subcategory</option>
                      {subCategories.map((c) => (
                        <option key={c.id} value={c.id}>{c.name}</option>
                      ))}
                    </select>
                    <ChevronDown size={14} className="absolute right-3 top-3 text-slate-400 pointer-events-none" />
                  </div>
                  {subCategories.length === 0 && (
                    <p className="text-[10px] text-amber-600">No subcategories found for the selected category.</p>
                  )}
                </div>
              )}

              {/* UI Type + Data Type row */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">UI Type</label>
                  <div className="relative">
                    <select
                      value={formData.ui_type}
                      onChange={(e) => setFormData({ ...formData, ui_type: e.target.value })}
                      className="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 focus:outline-none focus:border-violet-500 focus:ring-2 focus:ring-violet-500/10 text-sm appearance-none cursor-pointer transition-all pr-8"
                    >
                      {UI_TYPE_OPTIONS.map((u) => (
                        <option key={u.value} value={u.value}>{u.label}</option>
                      ))}
                    </select>
                    <ChevronDown size={14} className="absolute right-3 top-3 text-slate-400 pointer-events-none" />
                  </div>
                </div>
                <div className="space-y-1.5">
                  <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">Data Type</label>
                  <div className="relative">
                    <select
                      value={formData.data_type}
                      onChange={(e) => setFormData({ ...formData, data_type: e.target.value })}
                      className="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 focus:outline-none focus:border-violet-500 focus:ring-2 focus:ring-violet-500/10 text-sm appearance-none cursor-pointer transition-all pr-8"
                    >
                      {DATA_TYPE_OPTIONS.map((d) => (
                        <option key={d.value} value={d.value}>{d.label}</option>
                      ))}
                    </select>
                    <ChevronDown size={14} className="absolute right-3 top-3 text-slate-400 pointer-events-none" />
                  </div>
                </div>
              </div>

              {/* Options (only for select/chip types) */}
              {optionsNeedInput(formData.ui_type) && (
                <div className="space-y-1.5 animate-in slide-in-from-top-2 duration-200">
                  <div className="flex items-center justify-between gap-2">
                    <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                      Option Values <span className="text-slate-300">(comma separated)</span>
                    </label>
                    <button
                      type="button"
                      onClick={discoverOptions}
                      disabled={!formData.key.trim() || discovering}
                      className="flex items-center gap-1 text-[10px] font-bold text-violet-600 hover:text-violet-700 disabled:text-slate-300 disabled:cursor-not-allowed cursor-pointer"
                      title="Read the values products already store under this key"
                    >
                      {discovering ? <Loader2 size={11} className="animate-spin" /> : <Search size={11} />}
                      Fill from catalog
                    </button>
                  </div>
                  <input
                    type="text"
                    placeholder={formData.data_type === 'number' ? 'e.g. 250, 350, 500, 750' : 'e.g. Borosil, Milton, Treo'}
                    value={formData.options}
                    onChange={(e) => setFormData({ ...formData, options: e.target.value })}
                    className="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 focus:outline-none focus:border-violet-500 focus:ring-2 focus:ring-violet-500/10 text-sm transition-all placeholder-slate-300"
                  />
                  {/* Options must match the values products actually store, or the
                      filter renders in the app and matches nothing. */}
                  {discovered !== null && (
                    <p className={`text-[10px] font-medium ${discovered.length ? 'text-emerald-600' : 'text-amber-600'}`}>
                      {discovered.length
                        ? `Found ${discovered.length} value${discovered.length === 1 ? '' : 's'} in use: ${discovered.map((d) => `${d.value} (${d.count})`).join(', ')}`
                        : 'No product uses this key yet — add the attribute to products first, or type the options manually.'}
                    </p>
                  )}
                  {formData.options && (
                    <div className="flex flex-wrap gap-1.5 pt-1">
                      {formData.options.split(',').map((o, i) => o.trim() && (
                        <span key={i} className="bg-violet-50 text-violet-700 border border-violet-200 px-2 py-0.5 rounded-full text-[10px] font-semibold">
                          {o.trim()}
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              )}

              {/* Sort Order */}
              <div className="space-y-1.5">
                <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">Sort Order</label>
                <input
                  type="number"
                  min="0"
                  value={formData.sort_order}
                  onChange={(e) => setFormData({ ...formData, sort_order: e.target.value })}
                  className="w-24 px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 focus:outline-none focus:border-violet-500 focus:ring-2 focus:ring-violet-500/10 text-sm transition-all"
                />
                <p className="text-[10px] text-slate-400">Lower numbers appear first in the filter panel.</p>
              </div>

              {/* Behaviour Flags */}
              <div className="space-y-3 pt-1 border-t border-slate-100">
                <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">Behaviour</label>
                <div className="space-y-2.5">
                  {[
                    { key: 'show_in_mobile_filters', label: 'Show in Mobile Filter Drawer', hint: 'Appears as a filter option for buyers in the app' },
                    { key: 'is_required',            label: 'Required in Add Product',       hint: 'Product cannot be saved without filling this attribute' },
                    { key: 'is_searchable',          label: 'Searchable (future)',            hint: 'Enables text search within this filter\'s options' },
                  ].map(({ key, label, hint }) => (
                    <label key={key} className="flex items-start gap-3 cursor-pointer group">
                      <button
                        type="button"
                        onClick={() => setFormData(prev => ({ ...prev, [key]: !prev[key] }))}
                        className={`relative w-9 h-5 rounded-full transition-colors flex-shrink-0 mt-0.5 ${
                          formData[key] ? 'bg-violet-600' : 'bg-slate-200'
                        }`}
                      >
                        <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${
                          formData[key] ? 'translate-x-4' : 'translate-x-0.5'
                        }`} />
                      </button>
                      <div>
                        <span className="text-xs font-semibold text-slate-700 group-hover:text-slate-900 block">{label}</span>
                        <span className="text-[10px] text-slate-400">{hint}</span>
                      </div>
                    </label>
                  ))}
                </div>
              </div>

              {/* Default Value */}
              <div className="space-y-1.5">
                <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                  Default Value <span className="text-slate-300 font-normal">(optional)</span>
                </label>
                <input
                  type="text"
                  placeholder="Pre-filled value shown in Add Product form"
                  value={formData.default_value}
                  onChange={(e) => setFormData({ ...formData, default_value: e.target.value })}
                  className="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 focus:outline-none focus:border-violet-500 focus:ring-2 focus:ring-violet-500/10 text-sm transition-all placeholder-slate-300"
                />
                <p className="text-[10px] text-slate-400">Will pre-populate this attribute when a product is created under the assigned category.</p>
              </div>

              {/* Actions */}
              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="flex-1 py-3 border border-slate-200 text-slate-600 font-semibold rounded-xl hover:bg-slate-50 transition-all text-sm cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="flex-[2] py-3 bg-violet-600 hover:bg-violet-700 disabled:bg-violet-400 text-white font-bold rounded-xl transition-all flex items-center justify-center gap-2 text-sm cursor-pointer shadow-md shadow-violet-600/10"
                >
                  {saving ? <Loader2 className="animate-spin" size={16} /> : <Save size={16} />}
                  {saving ? 'Saving...' : editingFilter ? 'Update Filter' : 'Create Filter'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default FilterManager;
