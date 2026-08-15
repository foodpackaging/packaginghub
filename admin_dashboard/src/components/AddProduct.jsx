import React, { useState, useEffect, useCallback } from 'react';
import { api } from '../apiClient';
import {
  Upload, Package, IndianRupee, Tag, Info, CheckCircle2,
  AlertCircle, X, ListFilter, Loader2, SlidersHorizontal, Star, Trash2
} from 'lucide-react';
import { uploadImage, deleteImage } from '../imageUpload';

const PRODUCT_INFO_SECTIONS_KEY = 'productInformationSections';

// ─── Filter UI Helpers ─────────────────────────────────────────────────────────

// Filters captured by dedicated top-level form fields — skip in attributes section
const SKIP_KEYS = new Set(['price', 'availability', 'discount', 'rating', 'brand']);

const AttributeField = ({ filter, value, onChange }) => {
  const { key, label, ui_type, data_type, options, is_required } = filter;
  const opts = Array.isArray(options) ? options : [];

  if (SKIP_KEYS.has(key)) return null;

  // ── Chip Multiselect ──
  if (ui_type === 'multiselect') {
    const selected = Array.isArray(value) ? value : [];
    const toggle = (opt) => {
      const next = selected.includes(opt)
        ? selected.filter((v) => v !== opt)
        : [...selected, opt];
      onChange(key, next);
    };
    return (
      <div className="space-y-2">
        <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
          {label}{is_required && <span className="text-rose-500 ml-0.5">*</span>}
        </label>
        <div className="flex flex-wrap gap-1.5">
          {opts.map((opt) => (
            <button
              key={String(opt)}
              type="button"
              onClick={() => toggle(opt)}
              className={`px-3 py-1.5 rounded-full text-xs font-semibold border transition-all cursor-pointer ${
                selected.includes(opt)
                  ? 'bg-violet-600 text-white border-violet-600'
                  : 'bg-slate-50 text-slate-600 border-slate-200 hover:border-violet-300'
              }`}
            >
              {String(opt)}
            </button>
          ))}
        </div>
        {opts.length === 0 && (
          <p className="text-[10px] text-slate-400 italic">No options configured — add them in Filter Manager.</p>
        )}
      </div>
    );
  }

  // ── Chip Single-select ──
  if (ui_type === 'chip-selection') {
    return (
      <div className="space-y-2">
        <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
          {label}{is_required && <span className="text-rose-500 ml-0.5">*</span>}
        </label>
        <div className="flex flex-wrap gap-1.5">
          {opts.map((opt) => (
            <button
              key={String(opt)}
              type="button"
              onClick={() => onChange(key, value === opt ? null : opt)}
              className={`px-3 py-1.5 rounded-full text-xs font-semibold border transition-all cursor-pointer ${
                value === opt
                  ? 'bg-indigo-600 text-white border-indigo-600'
                  : 'bg-slate-50 text-slate-600 border-slate-200 hover:border-indigo-300'
              }`}
            >
              {String(opt)}
            </button>
          ))}
        </div>
        {opts.length === 0 && (
          <p className="text-[10px] text-slate-400 italic">No options configured — add them in Filter Manager.</p>
        )}
      </div>
    );
  }

  // ── Dropdown Single-select ──
  if (ui_type === 'single-select') {
    return (
      <div className="space-y-2">
        <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
          {label}{is_required && <span className="text-rose-500 ml-0.5">*</span>}
        </label>
        <select
          value={value ?? ''}
          onChange={(e) => {
            const v = e.target.value;
            onChange(key, data_type === 'number' ? (v === '' ? null : Number(v)) : (v || null));
          }}
          className="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/10 text-sm appearance-none cursor-pointer transition-all"
        >
          <option value="">Select {label}</option>
          {opts.map((opt) => (
            <option key={String(opt)} value={String(opt)}>{String(opt)}</option>
          ))}
        </select>
      </div>
    );
  }

  // ── Range (two number inputs) ──
  if (ui_type === 'range') {
    const rangeVal = value && typeof value === 'object' ? value : { min: '', max: '' };
    return (
      <div className="space-y-2">
        <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
          {label} (Range){is_required && <span className="text-rose-500 ml-0.5">*</span>}
        </label>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <span className="text-[9px] text-slate-400 font-bold uppercase block mb-1">Min</span>
            <input
              type="number"
              placeholder="Min"
              value={rangeVal.min}
              onChange={(e) => onChange(key, { ...rangeVal, min: e.target.value === '' ? '' : Number(e.target.value) })}
              className="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/10 text-sm transition-all"
            />
          </div>
          <div>
            <span className="text-[9px] text-slate-400 font-bold uppercase block mb-1">Max</span>
            <input
              type="number"
              placeholder="Max"
              value={rangeVal.max}
              onChange={(e) => onChange(key, { ...rangeVal, max: e.target.value === '' ? '' : Number(e.target.value) })}
              className="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/10 text-sm transition-all"
            />
          </div>
        </div>
      </div>
    );
  }

  // ── Boolean (toggle) ──
  if (ui_type === 'boolean') {
    const isOn = value === true || value === 'true';
    return (
      <div className="flex items-center justify-between py-1">
        <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
          {label}{is_required && <span className="text-rose-500 ml-0.5">*</span>}
        </label>
        <button
          type="button"
          onClick={() => onChange(key, !isOn)}
          className={`relative w-10 h-5.5 rounded-full transition-colors cursor-pointer flex-shrink-0 ${isOn ? 'bg-emerald-500' : 'bg-slate-200'}`}
          style={{ height: '22px', width: '40px' }}
        >
          <span
            className={`absolute top-0.5 h-4.5 w-4.5 bg-white rounded-full shadow transition-all duration-200 ${isOn ? 'translate-x-5' : 'translate-x-0.5'}`}
            style={{ height: '18px', width: '18px' }}
          />
        </button>
      </div>
    );
  }

  // ── Star Rating ──
  if (ui_type === 'rating') {
    const rating = Number(value) || 0;
    return (
      <div className="space-y-2">
        <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
          {label}{is_required && <span className="text-rose-500 ml-0.5">*</span>}
        </label>
        <div className="flex gap-1">
          {[1, 2, 3, 4, 5].map((star) => (
            <button
              key={star}
              type="button"
              onClick={() => onChange(key, star === rating ? null : star)}
              className="cursor-pointer transition-transform hover:scale-110"
            >
              <Star
                size={20}
                className={star <= rating ? 'text-amber-400 fill-amber-400' : 'text-slate-200 fill-slate-200'}
              />
            </button>
          ))}
          {rating > 0 && (
            <button
              type="button"
              onClick={() => onChange(key, null)}
              className="text-[10px] text-slate-400 hover:text-slate-600 ml-1 cursor-pointer"
            >
              Clear
            </button>
          )}
        </div>
      </div>
    );
  }

  // ── Fallback: plain text input ──
  return (
    <div className="space-y-2">
      <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
        {label}{is_required && <span className="text-rose-500 ml-0.5">*</span>}
      </label>
      <input
        type={data_type === 'number' ? 'number' : 'text'}
        placeholder={`Enter ${label}`}
        value={value ?? ''}
        onChange={(e) =>
          onChange(key, data_type === 'number' ? (e.target.value === '' ? null : Number(e.target.value)) : e.target.value)
        }
        className="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/10 text-sm transition-all"
      />
    </div>
  );
};

// ─── Main Component ─────────────────────────────────────────────────────────────

const AddProduct = ({ editProduct, onCancel }) => {
  const [loading, setLoading]   = useState(false);
  const [success, setSuccess]   = useState(false);
  const [error, setError]       = useState('');
  const [categories, setCategories] = useState([]);

  const [selectedMainCategoryId, setSelectedMainCategoryId] = useState(() =>
    localStorage.getItem('preselectedAddCategoryId') || ''
  );
  const [selectedSubCategoryId, setSelectedSubCategoryId] = useState(() =>
    localStorage.getItem('preselectedAddSubCategoryId') || ''
  );

  const [formData, setFormData] = useState({
    name: '',
    brand: '',
    sku: '',
    price: '',
    discounted_price: '',
    description: '',
    unit: 'piece',
    stock_quantity: 100,
  });

  const [productImages, setProductImages] = useState([]); // { file: File|null, url: string, isMain: boolean, isExisting: boolean }
  const [imageUrlInput, setImageUrlInput] = useState('');

  // Dynamic filters fetched for the selected category/subcategory
  const [dynamicFilters, setDynamicFilters] = useState([]);
  const [loadingFilters, setLoadingFilters] = useState(false);
  // Attribute values keyed by filter.key
  const [attributes, setAttributes] = useState({});
  const [productInformationSections, setProductInformationSections] = useState([]);

  // ── Fetch categories ──
  useEffect(() => {
    const fetchCategories = async () => {
      const { categories: data } = await api.get('/categories?all=true');
      if (data) setCategories(data);
    };
    fetchCategories();
    localStorage.removeItem('preselectedAddCategoryId');
    localStorage.removeItem('preselectedAddSubCategoryId');
  }, []);

  // ── Fetch dynamic filters when subcategory (or category) changes ──
  // Delegates entirely to the backend's /filters endpoint (the same one the
  // mobile app uses) so admin and customer app can never disagree on scope matching.
  const fetchFilters = useCallback(async (subCatId, catId) => {
    if (!catId) {
      setDynamicFilters([]);
      return;
    }
    setLoadingFilters(true);
    try {
      const params = new URLSearchParams({ category_id: catId });
      if (subCatId) params.set('subcategory_id', subCatId);
      const { filters: scopedFilters } = await api.get(`/filters?${params.toString()}`);

      setDynamicFilters(scopedFilters || []);

      // Pre-populate default values (don't overwrite existing user edits)
      const defaults = {};
      (scopedFilters || []).forEach((f) => {
        if (f.default_value != null && f.default_value !== '' && !SKIP_KEYS.has(f.key)) {
          defaults[f.key] = f.data_type === 'boolean'
            ? f.default_value === 'true'
            : f.data_type === 'number'
              ? Number(f.default_value)
              : f.default_value;
        }
      });
      if (Object.keys(defaults).length > 0) {
        setAttributes((prev) => ({ ...defaults, ...prev }));
      }
    } catch (e) {
      console.error('Filter fetch error:', e);
      setDynamicFilters([]);
    }
    setLoadingFilters(false);
  }, []);

  useEffect(() => {
    setAttributes({});
    fetchFilters(selectedSubCategoryId, selectedMainCategoryId);
  }, [selectedSubCategoryId, selectedMainCategoryId, fetchFilters]);

  // ── Populate form when editing ──
  useEffect(() => {
    if (editProduct) {
      setFormData({
        name: editProduct.name || '',
        brand: editProduct.brand || '',
        sku: editProduct.sku || '',
        price: editProduct.price || '',
        discounted_price: editProduct.discounted_price || '',
        description: editProduct.description || '',
        unit: editProduct.unit || 'piece',
        stock_quantity: editProduct.stock_quantity || 100,
      });

      if (editProduct.category_id && categories.length > 0) {
        const productCat = categories.find((c) => String(c.id) === String(editProduct.category_id));
        if (productCat) {
          if (productCat.parent_id) {
            setSelectedMainCategoryId(String(productCat.parent_id));
            setSelectedSubCategoryId(String(productCat.id));
          } else {
            setSelectedMainCategoryId(String(productCat.id));
            setSelectedSubCategoryId('');
          }
        }
      }

      if (editProduct.attributes && typeof editProduct.attributes === 'object') {
        const { [PRODUCT_INFO_SECTIONS_KEY]: savedSections, ...filterAttributes } = editProduct.attributes;
        setAttributes(filterAttributes);
        setProductInformationSections(normalizeProductInformationSections(
          editProduct.productInformationSections ||
          editProduct.product_information_sections ||
          savedSections
        ));
      } else {
        setAttributes({});
        setProductInformationSections(normalizeProductInformationSections(
          editProduct.productInformationSections ||
          editProduct.product_information_sections
        ));
      }

      if (editProduct.images && editProduct.images.length > 0) {
        setProductImages(editProduct.images.map((url, idx) => ({
          file: null,
          url: url,
          isMain: idx === 0,
          isExisting: true
        })));
      } else {
        setProductImages([]);
      }
      setImageUrlInput('');
    } else {
      setFormData({ name: '', brand: '', sku: '', price: '', discounted_price: '', description: '', unit: 'piece', stock_quantity: 100 });
      setSelectedMainCategoryId((prev) => prev || localStorage.getItem('preselectedAddCategoryId') || '');
      setSelectedSubCategoryId((prev) => prev || localStorage.getItem('preselectedAddSubCategoryId') || '');
      setProductImages([]);
      setImageUrlInput('');
      setAttributes({});
      setProductInformationSections([]);
    }
  }, [editProduct, categories]);

  const handleImageChange = (e) => {
    const files = Array.from(e.target.files);
    if (files.length > 0) {
      const newImages = files.map(file => ({
        file,
        url: URL.createObjectURL(file),
        isMain: false,
        isExisting: false
      }));
      setProductImages(prev => {
        const combined = [...prev, ...newImages];
        if (combined.length > 0 && !combined.some(img => img.isMain)) {
          combined[0].isMain = true;
        }
        return combined;
      });
      setImageUrlInput('');
    }
  };

  const handleUrlChange = (e) => {
    setImageUrlInput(e.target.value);
  };
  
  const addImageUrl = () => {
    if (imageUrlInput.trim()) {
      setProductImages(prev => {
        const combined = [...prev, {
          file: null,
          url: imageUrlInput.trim(),
          isMain: false,
          isExisting: false
        }];
        if (combined.length > 0 && !combined.some(img => img.isMain)) {
          combined[0].isMain = true;
        }
        return combined;
      });
      setImageUrlInput('');
    }
  };

  const setMainImage = (index) => {
    setProductImages(prev => prev.map((img, i) => ({ ...img, isMain: i === index })));
  };

  const removeImage = (index) => {
    setProductImages(prev => {
      const next = [...prev];
      next.splice(index, 1);
      if (next.length > 0 && !next.some(img => img.isMain)) {
        next[0].isMain = true;
      }
      return next;
    });
  };

  const handleAttributeChange = (key, val) => {
    setAttributes((prev) => ({ ...prev, [key]: val }));
  };

  const makeSectionId = () => {
    if (window.crypto?.randomUUID) return window.crypto.randomUUID();
    return `section-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  };

  const normalizeProductInformationSections = (sections) => {
    if (!Array.isArray(sections)) return [];
    return sections
      .map((section, index) => ({
        id: section.id || makeSectionId(),
        heading: section.heading || '',
        content: section.content || '',
        order: Number(section.order ?? index + 1),
        isSaved: true,
      }))
      .sort((a, b) => a.order - b.order);
  };

  const addProductInformationSection = () => {
    setProductInformationSections((prev) => [
      ...prev,
      { id: makeSectionId(), heading: '', content: '', order: prev.length + 1, isSaved: false },
    ]);
  };

  const updateProductInformationSection = (id, field, value) => {
    setProductInformationSections((prev) =>
      prev.map((section) => section.id === id ? { ...section, [field]: value } : section)
    );
  };

  const deleteProductInformationSection = (id) => {
    setProductInformationSections((prev) =>
      prev.filter((section) => section.id !== id).map((section, index) => ({ ...section, order: index + 1 }))
    );
  };

  const moveProductInformationSection = (index, direction) => {
    setProductInformationSections((prev) => {
      const targetIndex = index + direction;
      if (targetIndex < 0 || targetIndex >= prev.length) return prev;
      const next = [...prev];
      [next[index], next[targetIndex]] = [next[targetIndex], next[index]];
      return next.map((section, nextIndex) => ({ ...section, order: nextIndex + 1 }));
    });
  };

  const buildProductInformationSections = () => {
    return productInformationSections
      .map((section, index) => ({
        id: section.id,
        heading: section.heading.trim(),
        content: section.content.trim(),
        order: index + 1,
      }))
      .filter((section) => section.heading && section.content);
  };

  // Build the cleaned attributes object (strip nulls/empty)
  const buildAttributes = () => {
    const clean = {};
    for (const [k, v] of Object.entries(attributes)) {
      if (k === PRODUCT_INFO_SECTIONS_KEY) continue;
      if (v === null || v === undefined || v === '') continue;
      if (Array.isArray(v) && v.length === 0) continue;
      clean[k] = v;
    }
    const sections = buildProductInformationSections();
    if (sections.length > 0) {
      clean[PRODUCT_INFO_SECTIONS_KEY] = sections;
    }
    return clean;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccess(false);

    if (productImages.length === 0) {
      setError('Please upload at least one product image or paste an image URL.');
      setLoading(false);
      return;
    }

    try {
      // Find deleted images (exist in editProduct.images but not in productImages)
      if (editProduct && editProduct.images) {
        const currentUrls = productImages.filter(img => img.isExisting).map(img => img.url);
        const deletedUrls = editProduct.images.filter(url => !currentUrls.includes(url));
        for (const url of deletedUrls) {
          await deleteImage(url);
        }
      }

      // Upload new images concurrently
      const finalImages = await Promise.all(productImages.map(async (img) => {
        if (img.isExisting) return { ...img };
        if (img.file) {
          const newUrl = await uploadImage(img.file, 'products');
          return { ...img, url: newUrl };
        }
        return { ...img };
      }));
      
      // Sort so main is first
      const sortedUrls = finalImages
        .sort((a, b) => (a.isMain === b.isMain ? 0 : a.isMain ? -1 : 1))
        .map(img => img.url);

      const originalPrice  = parseFloat(formData.price);
      const salePrice      = parseFloat(formData.discounted_price) || originalPrice;
      const discountPercent = originalPrice > salePrice
        ? Math.round(((originalPrice - salePrice) / originalPrice) * 100)
        : 0;

      const finalCategoryId = selectedSubCategoryId || selectedMainCategoryId || null;

      const productData = {
        name:             formData.name,
        brand:            formData.brand?.trim() || null,
        sku:              formData.sku?.trim()   || null,
        price:            originalPrice,
        discounted_price: salePrice,
        discount_percent: discountPercent,
        description:      formData.description,
        unit:             formData.unit,
        stock_quantity:   parseInt(formData.stock_quantity),
        category_id:      finalCategoryId,
        images:           sortedUrls,
        slug:             formData.name.toLowerCase().replace(/ /g, '-'),
        is_active:        editProduct ? editProduct.is_active : true,
        attributes:       buildAttributes(),
      };

      if (editProduct) {
        await api.patch(`/products/${editProduct.id}`, productData);
      } else {
        await api.post('/products', productData);
      }

      setSuccess(true);
      if (!editProduct) {
        setFormData({ name: '', price: '', discounted_price: '', description: '', unit: 'piece', stock_quantity: 100 });
        setSelectedMainCategoryId('');
        setSelectedSubCategoryId('');
        setProductImages([]);
        setImageUrlInput('');
        setAttributes({});
        setProductInformationSections([]);
      } else {
        setTimeout(() => onCancel(), 1500);
      }
    } catch (err) {
      console.error(err);
      setError(err.message || 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  const mainCategories = categories.filter((c) => !c.parent_id);
  const subCategories  = categories.filter((c) => c.parent_id && String(c.parent_id) === String(selectedMainCategoryId));

  // Filters visible in attribute section (skip auto-generated global ones)
  const attributeFilters = dynamicFilters.filter((f) => !SKIP_KEYS.has(f.key));

  return (
    <div className="w-full font-sans animate-in fade-in duration-500">
      <div className="flex items-center justify-between pb-6 border-b border-slate-100 mb-8">
        <div>
          <h2 className="text-xl font-bold text-slate-900 tracking-tight">
            {editProduct ? 'Edit Product' : 'Add New Product'}
          </h2>
          <p className="text-slate-500 text-sm font-normal">Organize your shop catalog efficiently</p>
        </div>
        {editProduct && (
          <button onClick={onCancel} className="p-2 text-slate-400 hover:text-slate-600 transition-colors rounded-xl hover:bg-slate-50">
            <X size={20} />
          </button>
        )}
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {success && (
          <div className="flex items-center space-x-2 bg-emerald-50 border border-emerald-100 text-emerald-600 p-4 rounded-xl text-sm font-medium">
            <CheckCircle2 className="h-4.5 w-4.5" />
            <span>Product {editProduct ? 'updated' : 'added'} successfully!</span>
          </div>
        )}
        {error && (
          <div className="flex items-center space-x-2 bg-rose-50 border border-rose-100 text-rose-600 p-4 rounded-xl text-sm font-medium">
            <AlertCircle className="h-4.5 w-4.5" />
            <span>Error: {error}</span>
          </div>
        )}

        {/* ─── Core Fields ─────────────────────────────────── */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="space-y-5">
            {/* Product Name */}
            <div>
              <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">Product Name</label>
              <div className="relative">
                <Tag className="absolute left-3.5 top-3.5 h-4.5 w-4.5 text-slate-400" />
                <input
                  type="text"
                  required
                  placeholder="e.g. Borosil Ceramic Mug 350ml"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="block w-full pl-11 pr-4 py-3 bg-white border border-slate-200 rounded-xl text-slate-800 placeholder-slate-400 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-sm"
                />
              </div>
            </div>

            {/* Brand + SKU (System Fields) */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">Brand</label>
                <input
                  type="text"
                  placeholder="e.g. Borosil, Lock & Lock"
                  value={formData.brand}
                  onChange={(e) => setFormData({ ...formData, brand: e.target.value })}
                  className="block w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-slate-800 placeholder-slate-400 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-sm"
                />
              </div>
              <div>
                <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">SKU <span className="text-slate-300 font-normal normal-case">(optional)</span></label>
                <input
                  type="text"
                  placeholder="e.g. BOR-MUG-350"
                  value={formData.sku}
                  onChange={(e) => setFormData({ ...formData, sku: e.target.value.toUpperCase().replace(/[^A-Z0-9-_]/g, '') })}
                  className="block w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-slate-800 placeholder-slate-400 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-sm font-mono"
                />
              </div>
            </div>

            {/* Category + Subcategory */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">Category</label>
                <div className="relative">
                  <ListFilter className="absolute left-3.5 top-3.5 h-4.5 w-4.5 text-slate-400" />
                  <select
                    value={selectedMainCategoryId}
                    required
                    onChange={(e) => { setSelectedMainCategoryId(e.target.value); setSelectedSubCategoryId(''); }}
                    className="block w-full pl-11 pr-10 py-3 bg-white border border-slate-200 rounded-xl text-slate-800 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-sm appearance-none cursor-pointer"
                  >
                    <option value="">Select Category</option>
                    {mainCategories.map((cat) => (
                      <option key={cat.id} value={cat.id}>{cat.name}</option>
                    ))}
                  </select>
                  <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-4 text-slate-400">
                    <svg className="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
                      <path d="M9.293 12.95l.707.707L15.657 8l-1.414-1.414L10 10.828 5.757 6.586 4.343 8z" />
                    </svg>
                  </div>
                </div>
              </div>

              {selectedMainCategoryId && subCategories.length > 0 ? (
                <div className="animate-in slide-in-from-top-2 duration-200">
                  <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">Sub-category</label>
                  <div className="relative">
                    <ListFilter className="absolute left-3.5 top-3.5 h-4.5 w-4.5 text-slate-400" />
                    <select
                      value={selectedSubCategoryId}
                      onChange={(e) => setSelectedSubCategoryId(e.target.value)}
                      className="block w-full pl-11 pr-10 py-3 bg-white border border-slate-200 rounded-xl text-slate-800 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-sm appearance-none cursor-pointer"
                    >
                      <option value="">No Sub-category</option>
                      {subCategories.map((sub) => (
                        <option key={sub.id} value={sub.id}>{sub.name}</option>
                      ))}
                    </select>
                    <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-4 text-slate-400">
                      <svg className="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
                        <path d="M9.293 12.95l.707.707L15.657 8l-1.414-1.414L10 10.828 5.757 6.586 4.343 8z" />
                      </svg>
                    </div>
                  </div>
                </div>
              ) : (
                selectedMainCategoryId && (
                  <div className="flex items-center text-slate-400 text-xs pl-1 h-[68px] pt-5">No sub-categories defined</div>
                )
              )}
            </div>

            {/* Price */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">Original Price (₹)</label>
                <div className="relative">
                  <span className="absolute left-3.5 top-3 text-slate-400 text-sm font-medium">₹</span>
                  <input type="number" step="0.01" required placeholder="299.00" value={formData.price}
                    onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                    className="block w-full pl-8 pr-4 py-3 bg-white border border-slate-200 rounded-xl text-slate-800 placeholder-slate-400 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-sm" />
                </div>
              </div>
              <div>
                <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">Discount Price (₹)</label>
                <div className="relative">
                  <span className="absolute left-3.5 top-3 text-slate-400 text-sm font-medium">₹</span>
                  <input type="number" step="0.01" required placeholder="249.00" value={formData.discounted_price}
                    onChange={(e) => setFormData({ ...formData, discounted_price: e.target.value })}
                    className="block w-full pl-8 pr-4 py-3 bg-white border border-slate-200 rounded-xl text-slate-800 placeholder-slate-400 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-sm" />
                </div>
              </div>
            </div>

            {/* Stock */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">Stock Qty</label>
                <input type="number" required placeholder="100" value={formData.stock_quantity}
                  onChange={(e) => setFormData({ ...formData, stock_quantity: e.target.value })}
                  className="block w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-slate-800 placeholder-slate-400 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-sm" />
              </div>
            </div>
          </div>

          {/* ─── Image Upload ─────────────────────────────────── */}
          <div>
            <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">Product Images</label>
            
            {/* Image Grid */}
            <div className="grid grid-cols-2 lg:grid-cols-3 gap-4 mb-4">
              {productImages.map((img, index) => (
                <div key={index} className={`relative group rounded-xl overflow-hidden border-2 ${img.isMain ? 'border-indigo-500 shadow-md' : 'border-slate-200'} aspect-square bg-slate-50`}>
                  <img src={img.url} alt={`Preview ${index}`} className="w-full h-full object-cover" />
                  
                  {/* Overlay Controls */}
                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col justify-between p-2">
                    <div className="flex justify-between w-full">
                      <button
                        type="button"
                        onClick={() => setMainImage(index)}
                        className={`p-1.5 rounded-lg text-xs font-medium flex items-center gap-1 backdrop-blur-md transition-colors ${img.isMain ? 'bg-indigo-500 text-white' : 'bg-white/20 text-white hover:bg-white/40'}`}
                      >
                        <Star size={14} className={img.isMain ? "fill-white" : ""} />
                        {img.isMain ? "Main" : "Set Main"}
                      </button>
                      <button
                        type="button"
                        onClick={() => removeImage(index)}
                        className="p-1.5 rounded-lg bg-rose-500/80 text-white hover:bg-rose-600 backdrop-blur-md transition-colors"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </div>
                  {/* Main Badge for non-hover state */}
                  {img.isMain && (
                    <div className="absolute top-2 left-2 bg-indigo-500 text-white text-[10px] font-bold px-2 py-1 rounded-md shadow-sm pointer-events-none">
                      MAIN
                    </div>
                  )}
                </div>
              ))}
              
              {/* Add New Image Button */}
              <div className="relative border-2 border-dashed border-slate-200 hover:border-indigo-500 rounded-xl aspect-square flex flex-col items-center justify-center bg-slate-50/50 hover:bg-white transition-all group cursor-pointer overflow-hidden">
                <Upload className="h-6 w-6 text-slate-400 group-hover:text-indigo-600 transition-colors mb-2" />
                <span className="text-slate-500 text-xs font-medium text-center px-2">Upload Image</span>
                <input type="file" accept="image/*" multiple onChange={handleImageChange} className="absolute inset-0 opacity-0 cursor-pointer" />
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">Or Paste Image URL</label>
              <div className="flex gap-2">
                <input type="url" placeholder="https://example.com/image.jpg" value={imageUrlInput} onChange={handleUrlChange}
                  className="flex-1 px-4 py-3 bg-white border border-slate-200 rounded-xl text-slate-800 placeholder-slate-400 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-sm" />
                <button type="button" onClick={addImageUrl} className="px-5 py-3 bg-slate-100 hover:bg-slate-200 text-slate-700 font-semibold rounded-xl text-sm transition-colors">
                  Add
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* ─── Dynamic Product Attributes ──────────────────── */}
        <div className="bg-white border border-slate-100 rounded-2xl p-6 space-y-5">
          <div className="flex items-center justify-between border-b border-slate-100 pb-4">
            <div>
              <h3 className="font-bold text-slate-800 text-sm">Product Information Sections</h3>
              <p className="text-xs text-slate-400 mt-1">Custom product detail blocks shown on the mobile product page.</p>
            </div>
            <button
              type="button"
              onClick={addProductInformationSection}
              className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-xs font-semibold transition-all cursor-pointer"
            >
              + Add Section
            </button>
          </div>

          {productInformationSections.length === 0 ? (
            <div className="text-sm text-slate-400 bg-slate-50 border border-dashed border-slate-200 rounded-xl p-4">
              No product information sections added.
            </div>
          ) : (
            <div className="space-y-4">
              {productInformationSections.map((section, index) => (
                <div key={section.id} className="border border-slate-100 rounded-2xl p-4 bg-slate-50/60 space-y-3">
                  <div className="flex items-center justify-between gap-3">
                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
                      Section {index + 1}
                    </span>
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => moveProductInformationSection(index, -1)}
                        disabled={index === 0}
                        className="px-2 py-1 text-xs rounded-lg border border-slate-200 text-slate-500 disabled:opacity-40 disabled:cursor-not-allowed hover:bg-white cursor-pointer"
                      >
                        Up
                      </button>
                      <button
                        type="button"
                        onClick={() => moveProductInformationSection(index, 1)}
                        disabled={index === productInformationSections.length - 1}
                        className="px-2 py-1 text-xs rounded-lg border border-slate-200 text-slate-500 disabled:opacity-40 disabled:cursor-not-allowed hover:bg-white cursor-pointer"
                      >
                        Down
                      </button>
                      {section.isSaved ? (
                        <button
                          type="button"
                          onClick={() => updateProductInformationSection(section.id, 'isSaved', false)}
                          className="px-2 py-1 text-xs rounded-lg border border-indigo-100 text-indigo-600 hover:bg-indigo-50 cursor-pointer font-medium"
                        >
                          Edit
                        </button>
                      ) : (
                        <button
                          type="button"
                          onClick={() => updateProductInformationSection(section.id, 'isSaved', true)}
                          className="px-2 py-1 text-xs rounded-lg border border-emerald-100 bg-emerald-50 text-emerald-600 hover:bg-emerald-100 cursor-pointer font-medium flex items-center gap-1"
                        >
                          <CheckCircle2 size={12} /> Save
                        </button>
                      )}
                      <button
                        type="button"
                        onClick={() => deleteProductInformationSection(section.id)}
                        className="px-2 py-1 text-xs rounded-lg border border-rose-100 text-rose-600 hover:bg-rose-50 cursor-pointer"
                      >
                        Delete Section
                      </button>
                    </div>
                  </div>
                  
                  {section.isSaved ? (
                    <div className="bg-white border border-slate-100 rounded-xl p-4">
                      <h4 className="font-semibold text-slate-800 text-sm mb-1">{section.heading || 'No Heading'}</h4>
                      <p className="text-slate-500 text-sm">{section.content || 'No Content'}</p>
                    </div>
                  ) : (
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div>
                        <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">Section Heading</label>
                        <input
                          type="text"
                          placeholder="e.g. Custom heading"
                          value={section.heading}
                          onChange={(e) => updateProductInformationSection(section.id, 'heading', e.target.value)}
                          className="block w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-slate-800 placeholder-slate-400 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-sm"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 pl-1">Section Content</label>
                        <textarea
                          rows="2"
                          placeholder="e.g. Food-grade stainless steel"
                          value={section.content}
                          onChange={(e) => updateProductInformationSection(section.id, 'content', e.target.value)}
                          className="block w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-slate-800 placeholder-slate-400 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-sm"
                        />
                      </div>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>

        {(loadingFilters || attributeFilters.length > 0) && (
          <div className="bg-slate-50/60 border border-slate-100 rounded-2xl p-6 space-y-5 animate-in slide-in-from-bottom-2 duration-300">
            <div className="flex items-center justify-between border-b border-slate-100 pb-4">
              <div className="flex items-center gap-2">
                <SlidersHorizontal size={16} className="text-violet-600" />
                <h3 className="font-bold text-slate-800 text-sm">Product Attributes</h3>
                <span className="text-[10px] font-semibold text-slate-400 bg-slate-100 px-2 py-0.5 rounded-full">
                  Dynamic · from Filter Manager
                </span>
              </div>
              {loadingFilters && <Loader2 size={14} className="animate-spin text-indigo-500" />}
            </div>

            {loadingFilters && attributeFilters.length === 0 ? (
              <div className="py-6 flex items-center justify-center gap-2 text-slate-400 text-xs">
                <Loader2 size={14} className="animate-spin" />
                Loading filters for this category...
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-x-6 gap-y-5">
                {attributeFilters.map((filter) => (
                  <AttributeField
                    key={filter.key}
                    filter={filter}
                    value={attributes[filter.key] ?? null}
                    onChange={handleAttributeChange}
                  />
                ))}
              </div>
            )}

            {/* Preview of attribute JSON */}
            {Object.keys(buildAttributes()).length > 0 && (
              <div className="pt-3 border-t border-slate-100">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1.5 flex items-center gap-1">
                  <Info size={10} /> Saved as <code className="font-mono">attributes</code> on product
                </span>
                <pre className="text-[10px] text-slate-600 bg-white border border-slate-100 rounded-xl p-3 overflow-x-auto font-mono leading-relaxed">
                  {JSON.stringify(buildAttributes(), null, 2)}
                </pre>
              </div>
            )}
          </div>
        )}

        {/* No filters hint */}
        {!loadingFilters && attributeFilters.length === 0 && selectedMainCategoryId && (
          <div className="flex items-center gap-2 text-slate-400 text-xs bg-slate-50 border border-slate-100 rounded-xl p-4">
            <Info size={14} className="flex-shrink-0" />
            No dynamic filters are configured for this category/subcategory yet.
            Go to <strong className="text-violet-600">Filters tab</strong> to add them.
          </div>
        )}

        {/* ─── Submit ──────────────────────────────────────── */}
        <div className="flex gap-4 pt-4 border-t border-slate-100">
          {editProduct && (
            <button type="button" onClick={onCancel}
              className="flex-1 py-3.5 border border-slate-200 text-slate-600 font-semibold rounded-xl hover:bg-slate-50 transition-all text-sm cursor-pointer">
              Cancel
            </button>
          )}
          <button type="submit" disabled={loading}
            className="flex-[2] py-3.5 bg-indigo-600 hover:bg-indigo-700 disabled:bg-indigo-400 text-white font-semibold rounded-xl shadow-md shadow-indigo-600/10 transition-all flex items-center justify-center space-x-2 text-sm cursor-pointer">
            {loading ? <span>Saving...</span> : <span>{editProduct ? 'Update Product' : 'Publish Product'}</span>}
          </button>
        </div>
      </form>
    </div>
  );
};

export default AddProduct;
