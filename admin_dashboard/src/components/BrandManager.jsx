import React, { useState, useEffect } from 'react';
import { api } from '../apiClient';
import {
  Tag, Loader2, CheckCircle2, Trash2, Edit2, X, Package, ChevronRight
} from 'lucide-react';

const BrandManager = ({ setActiveTab }) => {
  const [brands, setBrands] = useState([]);
  const [loading, setLoading] = useState(true);
  const [success, setSuccess] = useState('');

  // Add brand state
  const [showAddModal, setShowAddModal] = useState(false);
  const [newBrand, setNewBrand] = useState('');
  const [adding, setAdding] = useState(false);

  // Edit brand state
  const [editingBrand, setEditingBrand] = useState(null); // { original, updated }
  const [editName, setEditName] = useState('');
  const [saving, setSaving] = useState(false);

  // Bulk delete
  const [isDeleteMode, setIsDeleteMode] = useState(false);
  const [selectedBrands, setSelectedBrands] = useState([]);

  // Brand detail panel
  const [activeBrand, setActiveBrand] = useState(null);
  const [brandProducts, setBrandProducts] = useState([]);
  const [loadingProducts, setLoadingProducts] = useState(false);

  // ─── Fetch all distinct brands from products ───────────────────────────────
  const fetchBrands = async () => {
    setLoading(true);
    try {
      const { brands: data } = await api.get('/products/brands');
      setBrands(data || []);
    } catch (err) {
      console.error(err);
    }
    setLoading(false);
  };

  useEffect(() => { fetchBrands(); }, []);

  // ─── Fetch products for a brand ─────────────────────────────────────────────
  const fetchBrandProducts = async (brand) => {
    setLoadingProducts(true);
    try {
      const { products: data } = await api.get(`/products?all=true&brand=${encodeURIComponent(brand)}`);
      setBrandProducts((data || []).slice().sort((a, b) => a.name.localeCompare(b.name)));
    } catch (err) {
      console.error(err);
    }
    setLoadingProducts(false);
  };

  useEffect(() => {
    if (activeBrand) fetchBrandProducts(activeBrand);
    else setBrandProducts([]);
  }, [activeBrand]);

  // ─── Add brand (renames all products with that new brand name) ──────────────
  const handleAdd = async (e) => {
    e.preventDefault();
    const trimmed = newBrand.trim();
    if (!trimmed) return;
    if (brands.includes(trimmed)) {
      alert('This brand already exists.');
      return;
    }
    setAdding(true);
    // There are no products yet for a brand-new name — just "register" it
    // by creating a placeholder product entry is not desirable.
    // Instead, we just add it as a known name in the list visually (it won't
    // persist until a product is assigned this brand in AddProduct).
    // So we show a friendly note instead.
    setAdding(false);
    setShowAddModal(false);
    setNewBrand('');
    alert(`"${trimmed}" will appear in the brand list once a product is assigned this brand name via the Add Product form.`);
  };

  // ─── Rename brand (update all products) ────────────────────────────────────
  const handleSaveEdit = async (e) => {
    e.preventDefault();
    const trimmed = editName.trim();
    if (!trimmed || !editingBrand) return;
    if (trimmed === editingBrand) {
      setEditingBrand(null);
      return;
    }
    setSaving(true);
    try {
      const { products: toRename } = await api.get(`/products?all=true&brand=${encodeURIComponent(editingBrand)}`);
      await Promise.all((toRename || []).map((p) => api.patch(`/products/${p.id}`, { brand: trimmed })));

      setSuccess(`Brand renamed to "${trimmed}"`);
      setTimeout(() => setSuccess(''), 3000);
      fetchBrands();
      if (activeBrand === editingBrand) setActiveBrand(trimmed);
    } catch (err) {
      alert('Error renaming brand: ' + err.message);
    }
    setEditingBrand(null);
    setEditName('');
    setSaving(false);
  };

  // ─── Bulk delete brands (sets brand = null on all products) ─────────────────
  const handleBulkDelete = async () => {
    if (selectedBrands.length === 0) return;
    if (!window.confirm(
      `Are you sure you want to remove the brand tag from all products in: ${selectedBrands.join(', ')}?`
    )) return;

    try {
      for (const brand of selectedBrands) {
        const { products: toClear } = await api.get(`/products?all=true&brand=${encodeURIComponent(brand)}`);
        await Promise.all((toClear || []).map((p) => api.patch(`/products/${p.id}`, { brand: null })));
      }
      setSelectedBrands([]);
      setIsDeleteMode(false);
      fetchBrands();
      setSuccess('Selected brands removed successfully.');
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      alert('Error removing brand tag: ' + err.message);
    }
  };

  // ─── Brand detail panel ─────────────────────────────────────────────────────
  if (activeBrand) {
    return (
      <div className="w-full space-y-8 font-sans animate-in fade-in duration-500">
        {/* Header */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-100">
          <div>
            <div className="flex items-center gap-2.5">
              <button
                onClick={() => setActiveBrand(null)}
                className="p-1.5 hover:bg-slate-100 rounded-lg text-slate-500 transition-colors cursor-pointer"
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M19 12H5"/><path d="m12 5-7 7 7 7"/></svg>
              </button>
              <h2 className="text-xl font-bold text-slate-900 tracking-tight flex items-center gap-2">
                <span>{activeBrand}</span>
                <span className="text-xs font-normal text-slate-400 bg-slate-100 px-2 py-0.5 rounded-full">Brand</span>
              </h2>
            </div>
            <p className="text-slate-500 text-sm font-normal mt-1">
              All products tagged with brand <span className="font-semibold text-indigo-600">{activeBrand}</span>
            </p>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={() => setActiveBrand(null)}
              className="flex items-center gap-2 bg-slate-50 hover:bg-slate-100 text-slate-600 px-5 py-2.5 rounded-xl font-semibold transition-all text-sm cursor-pointer border border-slate-200"
            >
              Back to Brands
            </button>
            <button
              onClick={() => {
                if (setActiveTab) setActiveTab('inventory');
              }}
              className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-5 py-2.5 rounded-xl font-semibold transition-all text-sm cursor-pointer shadow-md shadow-indigo-600/10"
            >
              <Package size={16} />
              View in Inventory
            </button>
          </div>
        </div>

        {/* Products List */}
        <div className="bg-white rounded-2xl border border-slate-100 shadow-sm p-6 space-y-4">
          <div className="flex justify-between items-center pb-3 border-b border-slate-100">
            <div>
              <h3 className="font-bold text-slate-800 text-sm flex items-center gap-1.5">
                <Package size={16} className="text-slate-400" />
                Products under this Brand
              </h3>
              <p className="text-slate-400 text-[11px] mt-0.5">All catalog items assigned to {activeBrand}.</p>
            </div>
            <span className="text-xs font-semibold text-slate-500 bg-slate-100 px-2.5 py-1 rounded-full">
              {brandProducts.length} Item{brandProducts.length !== 1 ? 's' : ''}
            </span>
          </div>

          {loadingProducts ? (
            <div className="py-12 flex flex-col items-center justify-center text-slate-400 gap-2">
              <Loader2 className="animate-spin text-indigo-600" size={24} />
              <p className="text-xs">Loading products...</p>
            </div>
          ) : (
            <div className="space-y-2 max-h-[60vh] overflow-y-auto pr-1">
              {brandProducts.map((prod) => (
                <div
                  key={prod.id}
                  className="flex items-center justify-between p-2.5 hover:bg-slate-50 rounded-xl border border-slate-100/50 gap-3 group transition-colors cursor-pointer"
                  onClick={() => setActiveTab && setActiveTab('inventory')}
                >
                  <div className="flex items-center gap-3">
                    <div className="h-10 w-10 bg-slate-50 rounded-lg overflow-hidden flex items-center justify-center border border-slate-100 flex-shrink-0">
                      {prod.images && prod.images[0] ? (
                        <img src={prod.images[0]} alt={prod.name} className="w-full h-full object-cover" />
                      ) : (
                        <Package size={14} className="text-slate-400" />
                      )}
                    </div>
                    <div className="min-w-0">
                      <span className="text-slate-800 font-semibold text-xs block truncate group-hover:text-indigo-600 transition-colors">{prod.name}</span>
                      <span className="text-[10px] text-slate-400 font-normal block mt-0.5 truncate">
                        SKU: {prod.sku || 'N/A'}
                      </span>
                    </div>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <span className="text-slate-900 font-bold text-xs block">₹{prod.discounted_price || prod.price}</span>
                    {prod.discounted_price && prod.discounted_price !== prod.price && (
                      <span className="text-[9px] text-slate-400 line-through block mt-0.5">₹{prod.price}</span>
                    )}
                  </div>
                </div>
              ))}
              {brandProducts.length === 0 && (
                <div className="py-12 text-center text-slate-400 text-xs border border-dashed border-slate-100 rounded-xl bg-slate-50/50">
                  No products tagged with this brand yet.
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    );
  }

  // ─── Main Brand List ────────────────────────────────────────────────────────
  return (
    <div className="w-full space-y-8 font-sans animate-in fade-in duration-500 relative">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-100">
        <div>
          <h2 className="text-xl font-bold text-slate-900 tracking-tight">Brands</h2>
          <p className="text-slate-500 text-sm font-normal">Brands are derived from your product catalog. Rename to update all products.</p>
        </div>
        <div className="flex items-center gap-3 self-start md:self-auto">
          {isDeleteMode ? (
            <>
              <button
                onClick={() => { setIsDeleteMode(false); setSelectedBrands([]); }}
                className="flex items-center gap-2 bg-slate-50 hover:bg-slate-100 text-slate-600 px-5 py-2.5 rounded-xl font-semibold transition-all text-sm cursor-pointer border border-slate-200"
              >
                Cancel
              </button>
              <button
                onClick={handleBulkDelete}
                disabled={selectedBrands.length === 0}
                className="flex items-center gap-2 bg-rose-600 hover:bg-rose-700 disabled:bg-rose-400 text-white px-5 py-2.5 rounded-xl font-semibold transition-all text-sm cursor-pointer shadow-md shadow-rose-600/10"
              >
                <Trash2 size={16} />
                Remove Brand Tag ({selectedBrands.length})
              </button>
            </>
          ) : (
            <>
              {brands.length > 0 && (
                <button
                  onClick={() => setIsDeleteMode(true)}
                  className="flex items-center gap-2 bg-slate-50 hover:bg-slate-100 text-slate-600 px-5 py-2.5 rounded-xl font-semibold transition-all text-sm cursor-pointer border border-slate-200"
                >
                  <Trash2 size={16} />
                  Remove Brand Tag
                </button>
              )}
            </>
          )}
        </div>
      </div>

      {/* Success banner */}
      {success && (
        <div className="flex items-center gap-2 text-emerald-600 bg-emerald-50 p-3.5 rounded-xl border border-emerald-100 text-sm font-medium animate-in slide-in-from-top-2 duration-200">
          <CheckCircle2 size={16} />
          <span>{success}</span>
        </div>
      )}

      {/* Info note */}
      <div className="flex items-start gap-3 bg-indigo-50/50 border border-indigo-100 rounded-xl p-4 text-sm text-indigo-700">
        <Tag size={16} className="mt-0.5 shrink-0 text-indigo-500" />
        <span>
          Brands are auto-discovered from your product <span className="font-semibold">brand</span> field.
          Renaming a brand here updates <span className="font-semibold">all products</span> with that brand.
          To add a new brand, assign it to a product via the <span className="font-semibold">Add Product</span> form.
        </span>
      </div>

      {/* List */}
      <div className="space-y-4">
        <div className="pb-4 border-b border-slate-100 flex justify-between items-center">
          <div className="flex items-center gap-3">
            {isDeleteMode && (
              <input
                type="checkbox"
                checked={brands.length > 0 && selectedBrands.length === brands.length}
                onChange={(e) => {
                  if (e.target.checked) setSelectedBrands([...brands]);
                  else setSelectedBrands([]);
                }}
                className="h-4 w-4 text-indigo-600 border-slate-200 rounded focus:ring-indigo-500/20 cursor-pointer"
              />
            )}
            <h3 className="font-medium text-slate-800 text-sm">All Brands</h3>
          </div>
          <span className="text-xs font-medium text-slate-500 bg-slate-100 px-2.5 py-1 rounded-full">{brands.length} Total</span>
        </div>

        {loading ? (
          <div className="p-10 text-center text-slate-400 flex flex-col items-center gap-3">
            <Loader2 className="animate-spin text-indigo-600" size={28} />
            <p className="text-sm">Loading brands...</p>
          </div>
        ) : (
          <div className="divide-y divide-slate-100">
            {brands.map((brand) => (
              <div key={brand} className="flex items-center justify-between py-4 hover:bg-slate-50/50 transition-colors group px-2 rounded-xl gap-4">
                {isDeleteMode && (
                  <div className="flex items-center gap-3 animate-in fade-in zoom-in duration-200">
                    <input
                      type="checkbox"
                      checked={selectedBrands.includes(brand)}
                      onChange={(e) => {
                        if (e.target.checked) setSelectedBrands([...selectedBrands, brand]);
                        else setSelectedBrands(selectedBrands.filter(b => b !== brand));
                      }}
                      className="h-4 w-4 text-indigo-600 border-slate-200 rounded focus:ring-indigo-500/20 cursor-pointer"
                    />
                  </div>
                )}

                <div
                  className="flex items-center gap-4 cursor-pointer flex-1"
                  onClick={() => setActiveBrand(brand)}
                >
                  {/* Brand avatar */}
                  <div className="h-12 w-12 bg-indigo-50 rounded-lg flex items-center justify-center text-indigo-600 font-black text-lg border border-indigo-100 group-hover:bg-indigo-100 transition-all select-none">
                    {brand.substring(0, 2).toUpperCase()}
                  </div>
                  <div>
                    <span className="text-slate-900 font-medium text-base block">{brand}</span>
                    <span className="text-xs text-slate-400 flex items-center gap-1 group-hover:text-indigo-600 transition-colors mt-0.5 font-normal">
                      Click to view products <ChevronRight size={12} />
                    </span>
                  </div>
                </div>

                <div className="flex items-center gap-1">
                  <button
                    onClick={() => { setEditingBrand(brand); setEditName(brand); }}
                    className="p-2 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-all cursor-pointer"
                  >
                    <Edit2 size={16} />
                  </button>
                </div>
              </div>
            ))}

            {brands.length === 0 && (
              <div className="p-20 text-center text-slate-400 text-sm font-normal">
                No brands found. Assign a brand to a product via the <strong>Add Product</strong> form.
              </div>
            )}
          </div>
        )}
      </div>

      {/* Edit Brand Modal */}
      {editingBrand && (
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-xs z-50 flex items-center justify-center p-4 animate-in fade-in duration-200">
          <div className="bg-white rounded-2xl max-w-md w-full border border-slate-100 shadow-2xl overflow-hidden animate-in zoom-in-95 duration-200">
            <div className="flex justify-between items-center px-6 py-4 border-b border-slate-100 bg-slate-50/50">
              <h3 className="font-semibold text-slate-900 text-base">Rename Brand</h3>
              <button
                type="button"
                onClick={() => { setEditingBrand(null); setEditName(''); }}
                className="p-1 hover:bg-slate-100 text-slate-400 hover:text-slate-600 rounded-lg transition-colors cursor-pointer"
              >
                <X size={18} />
              </button>
            </div>
            <form onSubmit={handleSaveEdit} className="p-6 space-y-5">
              <div className="space-y-2">
                <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider pl-1">Brand Name</label>
                <div className="relative">
                  <Tag className="absolute left-3.5 top-3.5 h-4 w-4 text-slate-400" />
                  <input
                    type="text"
                    required
                    value={editName}
                    onChange={(e) => setEditName(e.target.value)}
                    placeholder="Brand name"
                    className="w-full pl-11 pr-4 py-3 bg-white border border-slate-200 rounded-xl text-slate-800 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-sm placeholder-slate-400"
                  />
                </div>
                <p className="text-xs text-amber-600 bg-amber-50 border border-amber-100 rounded-lg px-3 py-2">
                  ⚠️ This will rename <strong>all products</strong> currently tagged as "{editingBrand}" to the new name.
                </p>
              </div>
              <div className="flex gap-3 pt-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => { setEditingBrand(null); setEditName(''); }}
                  className="flex-1 py-3 border border-slate-200 text-slate-600 font-semibold rounded-xl hover:bg-slate-50 transition-all text-xs cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={saving || !editName.trim()}
                  className="flex-1 py-3 bg-indigo-600 hover:bg-indigo-700 disabled:bg-indigo-400 text-white font-semibold rounded-xl transition-all flex items-center justify-center gap-2 text-xs cursor-pointer shadow-md shadow-indigo-600/10"
                >
                  {saving ? <Loader2 className="animate-spin" size={14} /> : <CheckCircle2 size={14} />}
                  Save
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default BrandManager;
