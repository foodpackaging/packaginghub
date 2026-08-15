import React, { useEffect, useState } from 'react';
import { api } from '../apiClient';
import { Edit2, Trash2, Package, Search, AlertCircle, Tag, ListFilter, SlidersHorizontal, X } from 'lucide-react';
import { deleteImage } from '../imageUpload';

const Inventory = ({ onEdit }) => {
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedMainCategoryId, setSelectedMainCategoryId] = useState(() => {
    return localStorage.getItem('preselectedCategoryId') || '';
  });
  const [selectedSubCategoryId, setSelectedSubCategoryId] = useState(() => {
    return localStorage.getItem('preselectedSubCategoryId') || '';
  });
  const [selectedStatus, setSelectedStatus] = useState(''); // '', 'active', 'inactive'
  const [activeFilterSelections, setActiveFilterSelections] = useState({});
  const [showAdvancedFilters, setShowAdvancedFilters] = useState(false);

  const fetchProducts = async () => {
    setLoading(true);
    try {
      const { products: data } = await api.get('/products?all=true');
      setProducts(data || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const fetchCategories = async () => {
    try {
      const { categories: data } = await api.get('/categories?all=true');
      setCategories(data || []);
    } catch (err) {
      console.error("Error fetching categories:", err);
    }
  };

  useEffect(() => {
    fetchProducts();
    fetchCategories();
    // Clear preselected categories from local storage so they don't persist on page reload
    localStorage.removeItem('preselectedCategoryId');
    localStorage.removeItem('preselectedSubCategoryId');
  }, []);

  const handleDelete = async (id) => {
    if (window.confirm('Are you sure you want to delete this product?')) {
      try {
        const productToDelete = products.find(p => p.id === id);
        await api.delete(`/products/${id}`);

        if (productToDelete && productToDelete.images && Array.isArray(productToDelete.images)) {
          for (const url of productToDelete.images) {
            await deleteImage(url);
          }
        }

        setProducts(products.filter(p => p.id !== id));
      } catch (err) {
        alert('Error deleting: ' + err.message);
      }
    }
  };

  const handleToggleActive = async (id, currentStatus) => {
    try {
      await api.patch(`/products/${id}`, { is_active: !currentStatus });
      setProducts(products.map(p => p.id === id ? { ...p, is_active: !currentStatus } : p));
    } catch (err) {
      alert('Error updating status: ' + err.message);
    }
  };

  const mainCategories = categories.filter(c => !c.parent_id);
  const subCategories = categories.filter(c => c.parent_id && String(c.parent_id) === String(selectedMainCategoryId));

  const activeMainCategory = categories.find(c => String(c.id) === String(selectedMainCategoryId));
  const activeSubCategory = categories.find(c => String(c.id) === String(selectedSubCategoryId));

  const commonFilterConfigs = activeMainCategory?.filter_configs || [];
  const specificFilterConfigs = activeSubCategory?.filter_configs || [];

  const getActiveFiltersCount = () => {
    let count = 0;
    Object.values(activeFilterSelections).forEach(val => {
      if (val === true) count++;
      if (Array.isArray(val) && val.length > 0) count += val.length;
    });
    return count;
  };

  const handleToggleBooleanFilter = (id) => {
    setActiveFilterSelections(prev => ({
      ...prev,
      [id]: prev[id] === true ? undefined : true
    }));
  };

  const handleToggleMultiselectOption = (id, option) => {
    setActiveFilterSelections(prev => {
      const current = prev[id] || [];
      const updated = current.includes(option)
        ? current.filter(opt => opt !== option)
        : [...current, option];
      return {
        ...prev,
        [id]: updated.length > 0 ? updated : undefined
      };
    });
  };

  const renderFilterInput = (cfg) => {
    const { id, name, type, options } = cfg;
    
    if (type === 'boolean') {
      const isChecked = activeFilterSelections[id] === true;
      return (
        <div key={id} className="flex items-center justify-between bg-white border border-slate-100 p-3 rounded-xl shadow-xs">
          <div className="flex flex-col">
            <span className="text-sm font-semibold text-slate-800">{name}</span>
            <span className="text-[10px] text-slate-400 font-normal mt-0.5">Yes/No switch filter</span>
          </div>
          <button
            type="button"
            onClick={() => handleToggleBooleanFilter(id)}
            className={`relative inline-flex h-5.5 w-10 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
              isChecked ? 'bg-indigo-600' : 'bg-slate-200'
            }`}
          >
            <span
              className={`pointer-events-none inline-block h-4.5 w-4.5 transform rounded-full bg-white shadow-sm ring-0 transition duration-200 ease-in-out ${
                isChecked ? 'translate-x-4.5' : 'translate-x-0'
              }`}
            />
          </button>
        </div>
      );
    }

    if (type === 'multiselect') {
      const selected = activeFilterSelections[id] || [];
      return (
        <div key={id} className="bg-white border border-slate-100 p-3 rounded-xl shadow-xs space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-sm font-semibold text-slate-800">{name}</span>
            {selected.length > 0 && (
              <span className="text-[10px] font-semibold text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded-full">
                {selected.length} Selected
              </span>
            )}
          </div>
          <div className="flex flex-wrap gap-1.5">
            {options.map((opt) => {
              const isSelected = selected.includes(opt);
              return (
                <button
                  key={opt}
                  type="button"
                  onClick={() => handleToggleMultiselectOption(id, opt)}
                  className={`text-xs px-2.5 py-1.5 rounded-lg border font-medium transition-all cursor-pointer ${
                    isSelected
                      ? 'bg-indigo-600 border-indigo-600 text-white shadow-xs'
                      : 'bg-slate-50 border-slate-200 text-slate-600 hover:bg-slate-100'
                  }`}
                >
                  {opt}
                </button>
              );
            })}
          </div>
        </div>
      );
    }

    return null;
  };

  const filteredProducts = products.filter(p => {
    const matchesSearch = 
      p.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      p.brand?.toLowerCase().includes(searchTerm.toLowerCase());
    
    // Category match
    let matchesCategory = true;
    if (selectedMainCategoryId !== '') {
      if (selectedSubCategoryId !== '') {
        // Must match subcategory exactly
        matchesCategory = String(p.category_id) === String(selectedSubCategoryId);
      } else {
        // Must match either main category exactly OR one of its subcategories
        const isMainMatch = String(p.category_id) === String(selectedMainCategoryId);
        const subIds = categories
          .filter(c => String(c.parent_id) === String(selectedMainCategoryId))
          .map(c => String(c.id));
        const isSubMatch = subIds.includes(String(p.category_id));
        matchesCategory = isMainMatch || isSubMatch;
      }
    }
    
    const matchesStatus = selectedStatus === '' || 
      (selectedStatus === 'active' && p.is_active) || 
      (selectedStatus === 'inactive' && !p.is_active);

    // Advanced dynamic filters match
    const matchesAdvancedFilters = Object.entries(activeFilterSelections).every(([filterId, selectionValue]) => {
      if (selectionValue === undefined || selectionValue === null) return true;

      // 1. Boolean filter type
      if (typeof selectionValue === 'boolean') {
        if (selectionValue === true) {
          if (filterId.includes('rating') || filterId.includes('rated')) {
            // Consistent rating hashing code based on product.id like Dart
            let hashCode = 0;
            const idStr = String(p.id);
            for (let i = 0; i < idStr.length; i++) {
              hashCode = idStr.charCodeAt(i) + ((hashCode << 5) - hashCode);
            }
            const ratingCode = Math.abs(hashCode) % 10;
            const rating = 3.5 + (ratingCode * 0.15);
            return rating >= 4.0;
          }
          
          const nameLower = p.name.toLowerCase();
          const descLower = (p.description || '').toLowerCase();
          const term = filterId.replace(/^is_/, '').replace(/_/g, ' ');
          return nameLower.includes(term) || descLower.includes(term);
        }
        return true;
      }

      // 2. Multiselect filter type
      if (Array.isArray(selectionValue) && selectionValue.length > 0) {
        if (filterId === 'brand') {
          return p.brand && selectionValue.some(opt => p.brand.toLowerCase().trim() === opt.toLowerCase().trim());
        }
        
        const nameLower = p.name.toLowerCase();
        const descLower = (p.description || '').toLowerCase();
        const brandLower = (p.brand || '').toLowerCase();
        const unitLower = (p.unit || '').toLowerCase();

        return selectionValue.some(option => {
          const optionLower = option.toLowerCase().trim();
          return nameLower.includes(optionLower) ||
                 descLower.includes(optionLower) ||
                 brandLower.includes(optionLower) ||
                 unitLower.includes(optionLower);
        });
      }

      return true;
    });
      
    return matchesSearch && matchesCategory && matchesStatus && matchesAdvancedFilters;
  });

  if (loading) return <div className="flex justify-center p-20 text-slate-400">Loading inventory...</div>;

  return (
    <div className="space-y-8 animate-in fade-in duration-500 font-sans">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-100">
        <div>
          <h2 className="text-xl font-bold text-slate-900 flex items-center gap-2 tracking-tight">
            Inventory Management
          </h2>
          <p className="text-slate-500 text-sm font-normal">Manage your live product catalog and sales</p>
        </div>
        
        <div className="flex flex-col sm:flex-row flex-wrap items-center gap-3 w-full md:w-auto">
          {/* Search bar */}
          <div className="relative w-full sm:w-64">
            <Search className="absolute left-3 top-2.5 h-4.5 w-4.5 text-slate-400" />
            <input
              type="text"
              placeholder="Search products..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-9.5 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-slate-800 placeholder-slate-400 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none text-sm font-normal transition-all"
            />
          </div>

          {/* Main Category Filter */}
          <div className="relative w-full sm:w-48">
            <ListFilter className="absolute left-3 top-2.5 h-4.5 w-4.5 text-slate-400 pointer-events-none" />
            <select
              value={selectedMainCategoryId}
              onChange={(e) => {
                setSelectedMainCategoryId(e.target.value);
                setSelectedSubCategoryId('');
                setActiveFilterSelections({});
              }}
              className="w-full pl-9.5 pr-8 py-2 bg-white border border-slate-200 rounded-xl text-slate-800 text-sm focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all cursor-pointer font-normal appearance-none"
            >
              <option value="">All Categories</option>
              {mainCategories.map((cat) => (
                <option key={cat.id} value={cat.id}>{cat.name}</option>
              ))}
            </select>
            <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-3 text-slate-400">
              <svg className="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
                <path d="M9.293 12.95l.707.707L15.657 8l-1.414-1.414L10 10.828 5.757 6.586 4.343 8z"/>
              </svg>
            </div>
          </div>

          {/* Sub-category Filter (Visible if subcategories exist) */}
          {selectedMainCategoryId && subCategories.length > 0 && (
            <div className="relative w-full sm:w-48 animate-in slide-in-from-left-2 duration-200">
              <ListFilter className="absolute left-3 top-2.5 h-4.5 w-4.5 text-slate-400 pointer-events-none" />
              <select
                value={selectedSubCategoryId}
                onChange={(e) => {
                  setSelectedSubCategoryId(e.target.value);
                  // Preserve common main category selections but clear any specific subcategory selections if switching
                  setActiveFilterSelections(prev => {
                    const next = { ...prev };
                    specificFilterConfigs.forEach(cfg => {
                      delete next[cfg.id];
                    });
                    return next;
                  });
                }}
                className="w-full pl-9.5 pr-8 py-2 bg-white border border-slate-200 rounded-xl text-slate-800 text-sm focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all cursor-pointer font-normal appearance-none"
              >
                <option value="">All Sub-categories</option>
                {subCategories.map((sub) => (
                  <option key={sub.id} value={sub.id}>{sub.name}</option>
                ))}
              </select>
              <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-3 text-slate-400">
                <svg className="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
                  <path d="M9.293 12.95l.707.707L15.657 8l-1.414-1.414L10 10.828 5.757 6.586 4.343 8z"/>
                </svg>
              </div>
            </div>
          )}

          {/* Status Filter */}
          <div className="relative w-full sm:w-40">
            <ListFilter className="absolute left-3 top-2.5 h-4.5 w-4.5 text-slate-400 pointer-events-none" />
            <select
              value={selectedStatus}
              onChange={(e) => setSelectedStatus(e.target.value)}
              className="w-full pl-9.5 pr-8 py-2 bg-white border border-slate-200 rounded-xl text-slate-800 text-sm focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all cursor-pointer font-normal appearance-none"
            >
              <option value="">All Statuses</option>
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
            </select>
            <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-3 text-slate-400">
              <svg className="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
                <path d="M9.293 12.95l.707.707L15.657 8l-1.414-1.414L10 10.828 5.757 6.586 4.343 8z"/>
              </svg>
            </div>
          </div>

          {/* Advanced Filters Toggle Button */}
          {selectedMainCategoryId && (commonFilterConfigs.length > 0 || specificFilterConfigs.length > 0) && (
            <button
              type="button"
              onClick={() => setShowAdvancedFilters(!showAdvancedFilters)}
              className={`flex items-center justify-center gap-2 px-4 py-2 border rounded-xl text-sm font-semibold transition-all cursor-pointer select-none shadow-xs ${
                showAdvancedFilters || getActiveFiltersCount() > 0
                  ? 'bg-indigo-50 border-indigo-200 text-indigo-700 hover:bg-indigo-100'
                  : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
              }`}
            >
              <SlidersHorizontal size={16} />
              <span>Filters</span>
              {getActiveFiltersCount() > 0 && (
                <span className="flex items-center justify-center h-5 px-1.5 min-w-5 text-[10px] font-bold text-white bg-indigo-600 rounded-full animate-in zoom-in duration-200">
                  {getActiveFiltersCount()}
                </span>
              )}
            </button>
          )}
        </div>
      </div>

      {/* Dynamic Advanced Filters Panel */}
      {showAdvancedFilters && selectedMainCategoryId && (commonFilterConfigs.length > 0 || specificFilterConfigs.length > 0) && (
        <div className="bg-slate-50/50 border border-slate-100 p-5 rounded-2xl space-y-4 animate-in slide-in-from-top-3 duration-300">
          <div className="flex items-center justify-between border-b border-slate-100 pb-3">
            <div className="flex items-center gap-2 text-slate-800 font-semibold text-sm">
              <SlidersHorizontal size={15} className="text-indigo-600" />
              <span>Category Specific Filters</span>
            </div>
            {getActiveFiltersCount() > 0 && (
              <button
                type="button"
                onClick={() => setActiveFilterSelections({})}
                className="text-xs text-rose-600 hover:text-rose-700 font-semibold flex items-center gap-1 cursor-pointer"
              >
                <X size={12} />
                Clear All
              </button>
            )}
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Common Category Filters */}
            {commonFilterConfigs.length > 0 && (
              <div className="space-y-4">
                <span className="block text-[11px] font-bold text-slate-400 uppercase tracking-wider pl-0.5">
                  Common Category Filters ({activeMainCategory?.name})
                </span>
                <div className="space-y-3.5">
                  {commonFilterConfigs.map((cfg) => renderFilterInput(cfg))}
                </div>
              </div>
            )}

            {/* Sub-category Specific Filters */}
            {selectedSubCategoryId && specificFilterConfigs.length > 0 && (
              <div className="space-y-4">
                <span className="block text-[11px] font-bold text-slate-400 uppercase tracking-wider pl-0.5">
                  Sub-category Specific Filters ({activeSubCategory?.name})
                </span>
                <div className="space-y-3.5">
                  {specificFilterConfigs.map((cfg) => renderFilterInput(cfg))}
                </div>
              </div>
            )}
            
            {/* If a main category is selected, subcategories exist, but no subcategory is selected yet */}
            {!selectedSubCategoryId && subCategories.length > 0 && specificFilterConfigs.length === 0 && (
              <div className="flex items-center justify-center p-6 border border-dashed border-slate-200 rounded-xl bg-white text-slate-400 text-xs">
                Select a Sub-category to unlock subcategory-specific filters
              </div>
            )}
          </div>
        </div>
      )}

      {error && (
        <div className="bg-rose-50 border border-rose-100 text-rose-600 p-4 rounded-xl flex items-center gap-2 text-sm font-normal">
          <AlertCircle size={18} />
          {error}
        </div>
      )}

      <div className="w-full overflow-x-auto">
        <table className="w-full text-left border-collapse">
          <thead className="border-b border-slate-100 text-[11px] font-semibold uppercase tracking-wider text-slate-400 bg-slate-50">
            <tr>
              <th className="py-4 pr-6 pl-4 whitespace-nowrap">Product</th>
              <th className="py-4 px-6 whitespace-nowrap">Category</th>
              <th className="py-4 px-6 whitespace-nowrap">Brand</th>
              <th className="py-4 px-6 whitespace-nowrap">Pricing</th>
              <th className="py-4 px-6 whitespace-nowrap">Inventory</th>
              <th className="py-4 px-6 whitespace-nowrap">Status</th>
              <th className="py-4 pr-4 text-right whitespace-nowrap">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filteredProducts.map((product) => {
              const category = categories.find(c => String(c.id) === String(product.category_id));
              let categoryDisplay = '—';
              if (category) {
                if (category.parent_id) {
                  const parent = categories.find(c => String(c.id) === String(category.parent_id));
                  categoryDisplay = parent ? `${parent.name} › ${category.name}` : category.name;
                } else {
                  categoryDisplay = category.name;
                }
              }
              return (
                <tr key={product.id} className="hover:bg-slate-50/40 transition-colors group">
                  <td className="py-4 pr-6 pl-2">
                    <div className="flex items-center gap-4">
                      <div className="h-12 w-12 rounded-lg bg-slate-50 overflow-hidden flex-shrink-0 border border-slate-100">
                        {product.images && product.images[0] ? (
                          <img src={product.images[0]} alt="" className="h-full w-full object-cover" />
                        ) : (
                          <div className="h-full w-full flex items-center justify-center text-slate-400">
                            <Package size={18} />
                          </div>
                        )}
                      </div>
                      <div className="max-w-[200px]">
                        <div className="font-medium text-slate-900 truncate text-sm" title={product.name}>{product.name}</div>
                        <div className="text-[10px] text-slate-400 font-mono mt-0.5">ID: {product.id}</div>
                      </div>
                    </div>
                  </td>
                  <td className="py-4 px-6 text-slate-600 text-sm font-normal">
                    <span className="inline-flex items-center bg-slate-50 text-slate-600 text-xs px-2 py-1 rounded-md font-medium border border-slate-100">
                      {categoryDisplay}
                    </span>
                  </td>
                  <td className="py-4 px-6 text-slate-600 text-sm font-normal">{product.brand || '—'}</td>
                  <td className="py-4 px-6">
                    <div className="flex flex-col">
                      <span className="text-indigo-600 font-semibold text-base leading-none">
                        ₹{parseFloat(product.discounted_price || product.price).toFixed(2)}
                      </span>
                      {product.discounted_price && product.discounted_price < product.price && (
                        <div className="flex items-center gap-1.5 mt-1">
                          <span className="text-slate-400 text-xs line-through">₹{parseFloat(product.price).toFixed(2)}</span>
                          <span className="text-emerald-600 text-[9px] bg-emerald-50 border border-emerald-100/50 px-1 py-0.5 rounded font-semibold uppercase">
                            {product.discount_percent}% off
                          </span>
                        </div>
                      )}
                    </div>
                  </td>
                  <td className="py-4 px-6">
                    <div className="flex items-center gap-2">
                      <div className={`w-2 h-2 rounded-full ${product.stock_quantity > 10 ? 'bg-emerald-500' : 'bg-rose-500 animate-pulse'}`}></div>
                      <span className="text-slate-600 text-sm font-normal">{product.stock_quantity} units</span>
                    </div>
                  </td>
                  <td className="py-4 px-6">
                    <button
                      onClick={() => handleToggleActive(product.id, product.is_active)}
                      className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                        product.is_active ? 'bg-indigo-600' : 'bg-slate-200'
                      }`}
                    >
                      <span
                        className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow-sm ring-0 transition duration-200 ease-in-out ${
                          product.is_active ? 'translate-x-5' : 'translate-x-0'
                        }`}
                      />
                    </button>
                  </td>
                  <td className="py-4 pr-2 text-right">
                    <div className="flex items-center justify-end gap-1">
                      <button 
                        onClick={() => onEdit(product)}
                        className="p-2 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-all cursor-pointer"
                      >
                        <Edit2 size={16} />
                      </button>
                      <button 
                        onClick={() => handleDelete(product.id)}
                        className="p-2 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-all cursor-pointer"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
        
        {filteredProducts.length === 0 && (
          <div className="p-20 text-center flex flex-col items-center justify-center space-y-4">
            <div className="bg-slate-50 p-4 rounded-full text-slate-400">
              <Search size={28} />
            </div>
            <p className="text-slate-500 font-medium text-sm">No products found. Try a different search term or filter.</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default Inventory;
