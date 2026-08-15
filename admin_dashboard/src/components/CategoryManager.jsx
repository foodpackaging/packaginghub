import React, { useState, useEffect } from 'react';
import { api } from '../apiClient';
import { FolderPlus, Trash2, Tag, Loader2, CheckCircle2, Upload, ChevronRight, ArrowLeft, X, Edit2, SlidersHorizontal, Package, ExternalLink } from 'lucide-react';
import { uploadImage, deleteImage } from '../imageUpload';

const CategoryManager = ({ setActiveTab }) => {
  const [categories, setCategories] = useState([]);
  const [selectedParent, setSelectedParent] = useState(null); // For nesting
  
  const [newCategory, setNewCategory] = useState('');
  const [imageFile, setImageFile] = useState(null);
  const [imagePreview, setImagePreview] = useState(null);
  const [imageUrlInput, setImageUrlInput] = useState('');
  const [loading, setLoading] = useState(true);
  const [adding, setAdding] = useState(false);
  const [success, setSuccess] = useState(false);
  const [showModal, setShowModal] = useState(false);

  // Bulk Delete selection
  const [isDeleteMode, setIsDeleteMode] = useState(false);
  const [selectedCategoryIds, setSelectedCategoryIds] = useState([]);

  // Category editing state
  const [editingCategory, setEditingCategory] = useState(null);
  const [editName, setEditName] = useState('');
  const [editImageFile, setEditImageFile] = useState(null);
  const [editImagePreview, setEditImagePreview] = useState(null);
  const [editImageUrlInput, setEditImageUrlInput] = useState('');
  const [saving, setSaving] = useState(false);

  // Active Sub-category Detail Page state
  const [activeSubCategory, setActiveSubCategory] = useState(null);
  const [subCategoryProducts, setSubCategoryProducts] = useState([]);
  const [loadingProducts, setLoadingProducts] = useState(false);

  const fetchSubCategoryProducts = async (subCatId) => {
    setLoadingProducts(true);
    try {
      const { products: data } = await api.get(`/products?all=true&category_id=${subCatId}`);
      setSubCategoryProducts((data || []).slice().sort((a, b) => a.name.localeCompare(b.name)));
    } catch (err) {
      console.error(err);
    }
    setLoadingProducts(false);
  };

  useEffect(() => {
    if (activeSubCategory) {
      fetchSubCategoryProducts(activeSubCategory.id);
    } else {
      setSubCategoryProducts([]);
    }
  }, [activeSubCategory]);

  const fetchCategories = async () => {
    setLoading(true);
    try {
      const parentParam = selectedParent ? selectedParent.id : 'null';
      const { categories: data } = await api.get(`/categories?all=true&parent_id=${parentParam}`);
      setCategories((data || []).slice().sort((a, b) => a.name.localeCompare(b.name)));
    } catch (err) {
      console.error(err);
    }
    setLoading(false);
  };

  useEffect(() => {
    setSelectedCategoryIds([]);
    setIsDeleteMode(false);
    fetchCategories();
  }, [selectedParent]);

  const handleImageChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setImageFile(file);
      setImagePreview(URL.createObjectURL(file));
      setImageUrlInput('');
    }
  };

  const handleUrlChange = (e) => {
    const url = e.target.value;
    setImageUrlInput(url);
    if (url.trim()) {
      setImagePreview(url.trim());
      setImageFile(null);
    } else {
      setImagePreview(null);
    }
  };

  const handleEditImageChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setEditImageFile(file);
      setEditImagePreview(URL.createObjectURL(file));
      setEditImageUrlInput('');
    }
  };

  const handleEditUrlChange = (e) => {
    const url = e.target.value;
    setEditImageUrlInput(url);
    if (url.trim()) {
      setEditImagePreview(url.trim());
      setEditImageFile(null);
    } else {
      setEditImagePreview(null);
    }
  };

  const handleStartEdit = (cat) => {
    setEditingCategory(cat);
    setEditName(cat.name);
    setEditImagePreview(cat.icon_url);
    setEditImageFile(null);
    setEditImageUrlInput(cat.icon_url || '');
  };

  const handleAdd = async (e) => {
    e.preventDefault();
    if (!newCategory.trim()) return;

    if (!imagePreview) {
      alert("Please upload a category icon or paste an image URL.");
      return;
    }
    
    setAdding(true);
    let imageUrl = imagePreview;

    try {
      if (imageFile) {
        imageUrl = await uploadImage(imageFile, 'categories');
      }

      await api.post('/categories', {
        name: newCategory.trim(),
        icon_url: imageUrl,
        parent_id: selectedParent ? selectedParent.id : null,
      });

      setNewCategory('');
      setImageFile(null);
      setImagePreview(null);
      setImageUrlInput('');
      fetchCategories();
      setSuccess(true);
      setShowModal(false);
      setTimeout(() => setSuccess(false), 3000);
    } catch (err) {
      console.error(err);
      alert('Error creating category: ' + err.message);
    }
    setAdding(false);
  };

  const handleSaveEdit = async (e) => {
    e.preventDefault();
    if (!editName.trim() || !editingCategory) return;

    if (!editImagePreview) {
      alert("Please upload a category icon or paste an image URL.");
      return;
    }
    
    setSaving(true);
    let imageUrl = editImagePreview;

    try {
      if (editImageFile) {
        if (editingCategory.icon_url) {
          await deleteImage(editingCategory.icon_url);
        }
        imageUrl = await uploadImage(editImageFile, 'categories');
      } else if (imageUrl !== editingCategory.icon_url) {
        if (editingCategory.icon_url) {
          await deleteImage(editingCategory.icon_url);
        }
      }

      await api.patch(`/categories/${editingCategory.id}`, {
        name: editName.trim(),
        icon_url: imageUrl,
      });

      setEditingCategory(null);
      setEditName('');
      setEditImageFile(null);
      setEditImagePreview(null);
      setEditImageUrlInput('');
      fetchCategories();
      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);
    } catch (err) {
      console.error(err);
      alert('Error saving category: ' + err.message);
    }
    setSaving(false);
  };

  const handleBulkDelete = async () => {
    if (selectedCategoryIds.length === 0) return;
    if (window.confirm(`Are you sure you want to delete the ${selectedCategoryIds.length} selected categories?`)) {
      try {
        const categoriesToDelete = categories.filter(c => selectedCategoryIds.includes(c.id));
        await Promise.all(selectedCategoryIds.map((id) => api.delete(`/categories/${id}`)));

        for (const cat of categoriesToDelete) {
          if (cat.icon_url) {
            await deleteImage(cat.icon_url);
          }
        }
        setSelectedCategoryIds([]);
        setIsDeleteMode(false);
        fetchCategories();
        setSuccess(true);
        setTimeout(() => setSuccess(false), 3000);
      } catch (err) {
        console.error(err);
        alert('Error deleting categories: ' + err.message);
      }
    }
  };

  if (activeSubCategory) {
    return (
      <div className="w-full space-y-8 font-sans animate-in fade-in duration-500 relative">
        {/* Header Breadcrumbs / Nav */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-100">
          <div>
            <div className="flex items-center gap-2.5">
              <button 
                onClick={() => setActiveSubCategory(null)}
                className="p-1.5 hover:bg-slate-100 rounded-lg text-slate-500 transition-colors cursor-pointer"
              >
                <ArrowLeft size={16} />
              </button>
              <h2 className="text-xl font-bold text-slate-900 tracking-tight flex items-center gap-2">
                <span>{activeSubCategory.name}</span>
                <span className="text-xs font-normal text-slate-400 bg-slate-100 px-2 py-0.5 rounded-full">Sub-category</span>
              </h2>
            </div>
            <p className="text-slate-500 text-sm font-normal mt-1">
              Manage products inside <span className="font-semibold text-slate-700">{selectedParent?.name}</span> &gt; <span className="font-semibold text-indigo-600">{activeSubCategory.name}</span>
            </p>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={() => setActiveSubCategory(null)}
              className="flex items-center gap-2 bg-slate-50 hover:bg-slate-100 text-slate-600 px-5 py-2.5 rounded-xl font-semibold transition-all text-sm cursor-pointer border border-slate-200 shadow-xs"
            >
              Back to Sub-categories
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
          {/* Left Column: Quick Actions & Filters Shortcut */}
          <div className="lg:col-span-4 space-y-6">
            <div className="bg-white rounded-2xl border border-slate-100 shadow-sm p-6 space-y-4">
              <h3 className="font-bold text-slate-800 text-base">Quick Operations</h3>
              
              <div className="grid grid-cols-1 gap-3">
                {/* Add Product Card */}
                <button
                  type="button"
                  onClick={() => {
                    localStorage.setItem('preselectedAddCategoryId', String(selectedParent.id));
                    localStorage.setItem('preselectedAddSubCategoryId', String(activeSubCategory.id));
                    if (setActiveTab) setActiveTab('add');
                  }}
                  className="flex items-start gap-4 p-4 text-left bg-slate-50 hover:bg-indigo-50/50 border border-slate-100 hover:border-indigo-200 rounded-xl transition-all cursor-pointer group"
                >
                  <div className="p-2.5 bg-white border border-slate-100 rounded-lg text-slate-400 group-hover:text-indigo-600 group-hover:border-indigo-100 transition-colors shadow-xs">
                    <FolderPlus size={20} />
                  </div>
                  <div>
                    <h4 className="text-sm font-bold text-slate-800 group-hover:text-indigo-700 transition-colors">Add New Product</h4>
                    <p className="text-xs text-slate-500 font-normal mt-1 leading-relaxed">
                      Add a new inventory item pre-mapped directly under {activeSubCategory.name}.
                    </p>
                  </div>
                </button>

                {/* View Products Card */}
                <button
                  type="button"
                  onClick={() => {
                    localStorage.setItem('preselectedCategoryId', String(selectedParent.id));
                    localStorage.setItem('preselectedSubCategoryId', String(activeSubCategory.id));
                    if (setActiveTab) setActiveTab('inventory');
                  }}
                  className="flex items-start gap-4 p-4 text-left bg-slate-50 hover:bg-emerald-50/50 border border-slate-100 hover:border-emerald-200 rounded-xl transition-all cursor-pointer group"
                >
                  <div className="p-2.5 bg-white border border-slate-100 rounded-lg text-slate-400 group-hover:text-emerald-600 group-hover:border-emerald-100 transition-colors shadow-xs">
                    <Package size={20} />
                  </div>
                  <div>
                    <h4 className="text-sm font-bold text-slate-800 group-hover:text-emerald-700 transition-colors">View Products</h4>
                    <p className="text-xs text-slate-500 font-normal mt-1 leading-relaxed">
                      Go to the product catalog dashboard filtered to this sub-category.
                    </p>
                  </div>
                </button>

                {/* Manage Filters Shortcut */}
                <button
                  type="button"
                  onClick={() => {
                    localStorage.setItem('adminActiveTab', 'filters');
                    if (setActiveTab) setActiveTab('filters');
                  }}
                  className="flex items-start gap-4 p-4 text-left bg-violet-50/50 hover:bg-violet-100/50 border border-violet-100 hover:border-violet-300 rounded-xl transition-all cursor-pointer group"
                >
                  <div className="p-2.5 bg-white border border-violet-100 rounded-lg text-violet-400 group-hover:text-violet-600 group-hover:border-violet-200 transition-colors shadow-xs">
                    <SlidersHorizontal size={20} />
                  </div>
                  <div>
                    <h4 className="text-sm font-bold text-violet-800 group-hover:text-violet-900 transition-colors">Manage Filters</h4>
                    <p className="text-xs text-violet-600/80 font-normal mt-1 leading-relaxed">
                      Open the Filter Manager to configure dynamic attributes for this subcategory.
                    </p>
                  </div>
                </button>
              </div>
            </div>
          </div>

          {/* Right Column: Sub-category Products Preview Panel */}
          <div className="lg:col-span-8 bg-white rounded-2xl border border-slate-100 shadow-sm p-6 space-y-4 flex flex-col">
            <div className="flex justify-between items-center pb-3 border-b border-slate-100">
              <div>
                <h3 className="font-bold text-slate-800 text-sm flex items-center gap-1.5">
                  <Package size={16} className="text-slate-400" />
                  Products in Sub-category
                </h3>
                <p className="text-slate-400 text-[11px] mt-0.5">Catalog preview currently under this branch.</p>
              </div>
              <span className="text-xs font-semibold text-slate-500 bg-slate-100 px-2.5 py-1 rounded-full">
                {subCategoryProducts.length} Item{subCategoryProducts.length !== 1 ? 's' : ''}
              </span>
            </div>

            {loadingProducts ? (
              <div className="py-12 flex flex-col items-center justify-center text-slate-400 gap-2">
                <Loader2 className="animate-spin text-indigo-600" size={24} />
                <p className="text-xs">Loading products...</p>
              </div>
            ) : (
              <div className="space-y-2 max-h-[60vh] overflow-y-auto pr-1">
                {subCategoryProducts.map((prod) => (
                  <div 
                    key={prod.id} 
                    className="flex items-center justify-between p-2.5 hover:bg-slate-50 rounded-xl border border-slate-100/50 gap-3 group transition-colors cursor-pointer"
                    onClick={() => {
                      localStorage.setItem('preselectedCategoryId', String(selectedParent.id));
                      localStorage.setItem('preselectedSubCategoryId', String(activeSubCategory.id));
                      if (setActiveTab) setActiveTab('inventory');
                    }}
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
                          {prod.brand ? `${prod.brand} • ` : ''}SKU: {prod.sku || 'N/A'}
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

                {subCategoryProducts.length === 0 && (
                  <div className="py-12 text-center text-slate-400 text-xs font-normal border border-dashed border-slate-100 rounded-xl bg-slate-50/50">
                    No products in this sub-category yet.<br />
                    <button 
                      onClick={() => {
                        localStorage.setItem('preselectedAddCategoryId', String(selectedParent.id));
                        localStorage.setItem('preselectedAddSubCategoryId', String(activeSubCategory.id));
                        if (setActiveTab) setActiveTab('add');
                      }}
                      className="text-indigo-600 hover:underline font-bold mt-1.5 inline-block cursor-pointer"
                    >
                      Create first product
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="w-full space-y-8 font-sans animate-in fade-in duration-500 relative">
      {/* Breadcrumbs / Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-100">
        <div>
          <div className="flex items-center gap-2.5">
            {selectedParent && (
              <button 
                onClick={() => setSelectedParent(null)}
                className="p-1.5 hover:bg-slate-100 rounded-lg text-slate-500 transition-colors cursor-pointer"
              >
                <ArrowLeft size={16} />
              </button>
            )}
            <h2 className="text-xl font-bold text-slate-900 tracking-tight">
              {selectedParent ? `Sub-categories of ${selectedParent.name}` : 'Categories'}
            </h2>
          </div>
          <p className="text-slate-500 text-sm font-normal">Organize your shop hierarchy and nesting</p>
        </div>

        <div className="flex items-center gap-3 self-start md:self-auto">
          {isDeleteMode ? (
            <>
              <button
                onClick={() => { setIsDeleteMode(false); setSelectedCategoryIds([]); }}
                className="flex items-center gap-2 bg-slate-50 hover:bg-slate-100 text-slate-600 px-5 py-2.5 rounded-xl font-semibold transition-all text-sm cursor-pointer border border-slate-200 shadow-xs"
              >
                Cancel
              </button>
              <button
                onClick={handleBulkDelete}
                disabled={selectedCategoryIds.length === 0}
                className="flex items-center gap-2 bg-rose-600 hover:bg-rose-700 disabled:bg-rose-400 text-white px-5 py-2.5 rounded-xl font-semibold transition-all text-sm cursor-pointer shadow-md shadow-rose-600/10"
              >
                <Trash2 size={16} />
                Confirm Delete ({selectedCategoryIds.length})
              </button>
            </>
          ) : (
            <>
              {categories.length > 0 && (
                <button
                  onClick={() => setIsDeleteMode(true)}
                  className="flex items-center gap-2 bg-slate-50 hover:bg-slate-100 text-slate-600 px-5 py-2.5 rounded-xl font-semibold transition-all text-sm cursor-pointer border border-slate-200 shadow-xs"
                >
                  <Trash2 size={16} />
                  Delete
                </button>
              )}
              <button
                onClick={() => setShowModal(true)}
                className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-5 py-2.5 rounded-xl font-semibold transition-all shadow-md shadow-indigo-600/10 text-sm cursor-pointer"
              >
                <FolderPlus size={16} />
                {selectedParent ? 'Add Sub-category' : 'Add Category'}
              </button>
            </>
          )}
        </div>
      </div>

      <div className="space-y-6">
        {success && (
          <div className="flex items-center gap-2 text-emerald-600 bg-emerald-50 p-3.5 rounded-xl border border-emerald-100 text-sm font-medium animate-in slide-in-from-top-2 duration-200">
            <CheckCircle2 size={16} />
            <span>Category updated successfully!</span>
          </div>
        )}
      </div>

      {/* List */}
      <div className="space-y-4">
        <div className="pb-4 border-b border-slate-100 flex justify-between items-center">
          <div className="flex items-center gap-3">
            {isDeleteMode && (
              <input 
                type="checkbox"
                checked={categories.length > 0 && selectedCategoryIds.length === categories.length}
                onChange={(e) => {
                  if (e.target.checked) {
                    setSelectedCategoryIds(categories.map(c => c.id));
                  } else {
                    setSelectedCategoryIds([]);
                  }
                }}
                className="h-4 w-4 text-indigo-600 border-slate-200 rounded focus:ring-indigo-500/20 cursor-pointer animate-in fade-in zoom-in duration-200"
              />
            )}
            <h3 className="font-medium text-slate-800 text-sm">
              {selectedParent ? `Contents of ${selectedParent.name}` : 'Main Level Categories'}
            </h3>
          </div>
          <span className="text-xs font-medium text-slate-500 bg-slate-100 px-2.5 py-1 rounded-full">{categories.length} Total</span>
        </div>
        
        {loading ? (
          <div className="p-10 text-center text-slate-400 flex flex-col items-center gap-3">
            <Loader2 className="animate-spin text-indigo-600" size={28} />
            <p className="text-sm">Loading...</p>
          </div>
        ) : (
          <div className="divide-y divide-slate-100">
            {categories.map((cat) => (
              <div key={cat.id} className="flex items-center justify-between py-4 hover:bg-slate-50/50 transition-colors group px-2 rounded-xl gap-4">
                {isDeleteMode ? (
                  <div className="flex items-center gap-3 animate-in fade-in zoom-in duration-200">
                    <input 
                      type="checkbox"
                      checked={selectedCategoryIds.includes(cat.id)}
                      onChange={(e) => {
                        if (e.target.checked) {
                          setSelectedCategoryIds([...selectedCategoryIds, cat.id]);
                        } else {
                          setSelectedCategoryIds(selectedCategoryIds.filter(id => id !== cat.id));
                        }
                      }}
                      className="h-4 w-4 text-indigo-600 border-slate-200 rounded focus:ring-indigo-500/20 cursor-pointer"
                    />
                  </div>
                ) : null}

                <div 
                  className="flex items-center gap-4 cursor-pointer flex-1"
                  onClick={() => {
                    if (!selectedParent) {
                      setSelectedParent(cat);
                    } else {
                      setActiveSubCategory(cat);
                    }
                  }}
                >
                  <div className="h-12 w-12 bg-slate-50 rounded-lg overflow-hidden flex items-center justify-center text-slate-400 group-hover:bg-indigo-50 group-hover:text-indigo-600 border border-slate-100 transition-all">
                    {cat.icon_url ? (
                      <img src={cat.icon_url} alt={cat.name} className="w-full h-full object-cover" />
                    ) : (
                      <Tag size={16} />
                    )}
                  </div>
                  <div>
                    <span className="text-slate-900 font-medium text-base block">{cat.name}</span>
                    {!selectedParent ? (
                      <span className="text-xs text-slate-400 flex items-center gap-1 group-hover:text-indigo-600 transition-colors mt-0.5 font-normal">
                        Click to manage sub-categories <ChevronRight size={12} />
                      </span>
                    ) : (
                      <span className="text-xs text-slate-400 flex items-center gap-1 group-hover:text-indigo-600 transition-colors mt-0.5 font-normal">
                        Click to view products <ChevronRight size={12} />
                      </span>
                    )}
                  </div>
                </div>
                
                <div className="flex items-center gap-1">
                  <button
                    onClick={() => handleStartEdit(cat)}
                    className="p-2 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-all cursor-pointer"
                  >
                    <Edit2 size={16} />
                  </button>
                </div>
              </div>
            ))}
            
            {categories.length === 0 && (
              <div className="p-20 text-center text-slate-400 text-sm font-normal">
                No items here yet. Click "+ Add Category" to insert one.
              </div>
            )}
          </div>
        )}
      </div>

      {/* Modern Pop-up Add Modal Dialog */}
      {showModal && (
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-xs z-50 flex items-center justify-center p-4 animate-in fade-in duration-200">
          <div className="bg-white rounded-2xl max-w-md w-full md:max-w-lg border border-slate-100 shadow-2xl overflow-hidden animate-in zoom-in-95 duration-200">
            {/* Modal Header */}
            <div className="flex justify-between items-center px-6 py-4.5 border-b border-slate-100 bg-slate-50/50">
              <h3 className="font-semibold text-slate-900 text-base">
                {selectedParent ? `Add Sub-category to ${selectedParent.name}` : 'Add New Category'}
              </h3>
              <button 
                type="button" 
                onClick={() => { setShowModal(false); setImageFile(null); setImagePreview(null); setImageUrlInput(''); setNewCategory(''); }}
                className="p-1 hover:bg-slate-100 text-slate-400 hover:text-slate-600 rounded-lg transition-colors cursor-pointer"
              >
                <X size={18} />
              </button>
            </div>

            {/* Modal Form */}
            <form onSubmit={handleAdd} className="p-6 space-y-5">
              {/* Category Name */}
              <div className="space-y-2">
                <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider pl-1">Category Name</label>
                <div className="relative">
                  <FolderPlus className="absolute left-3.5 top-3.5 h-4.5 w-4.5 text-slate-400" />
                  <input
                    type="text"
                    required
                    value={newCategory}
                    onChange={(e) => setNewCategory(e.target.value)}
                    placeholder="e.g. Cutlery, Kitchenware, Shirts"
                    className="w-full pl-11 pr-4 py-3 bg-white border border-slate-200 rounded-xl text-slate-800 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-sm placeholder-slate-400 font-normal"
                  />
                </div>
              </div>

              {/* Image Upload Area */}
              <div className="space-y-2">
                <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider pl-1">Category Icon / Image</label>
                <div className="relative border border-dashed border-slate-200 hover:border-indigo-500 rounded-xl h-40 flex flex-col items-center justify-center bg-slate-50/50 hover:bg-white transition-all group cursor-pointer overflow-hidden">
                  {imagePreview ? (
                    <img src={imagePreview} alt="Preview" className="w-full h-full object-cover animate-in fade-in duration-300" />
                  ) : (
                    <div className="flex flex-col items-center text-center p-4">
                      <Upload className="h-6 w-6 text-slate-400 group-hover:text-indigo-600 transition-colors mb-2" />
                      <span className="text-slate-600 text-xs font-medium">Click to upload icon</span>
                      <span className="text-slate-400 text-[10px] mt-0.5 font-normal">PNG or JPG up to 2MB</span>
                    </div>
                  )}
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleImageChange}
                    className="absolute inset-0 opacity-0 cursor-pointer"
                  />
                </div>
                <div>
                  <input
                    type="url"
                    placeholder="Or paste Category Image URL"
                    value={imageUrlInput}
                    onChange={handleUrlChange}
                    className="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-xs placeholder-slate-400 font-normal mt-2"
                  />
                </div>
              </div>

              {/* Info Note about filters */}
              <div className="pt-2">
                <p className="text-xs text-slate-500 flex gap-2 items-start bg-slate-50 p-3 rounded-lg border border-slate-100">
                  <ExternalLink size={14} className="text-indigo-500 mt-0.5 shrink-0" />
                  <span>Looking to add custom filters? Use the new <span className="font-semibold text-indigo-600">Filters tab</span> in the main navigation after creating this category.</span>
                </p>
              </div>

              {/* Action Buttons */}
              <div className="flex gap-3 pt-4 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => { setShowModal(false); setImageFile(null); setImagePreview(null); setImageUrlInput(''); setNewCategory(''); }}
                  className="flex-1 py-3 border border-slate-200 text-slate-600 font-semibold rounded-xl hover:bg-slate-50 transition-all text-xs cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={adding || !newCategory.trim()}
                  className="flex-1 py-3 bg-indigo-600 hover:bg-indigo-700 disabled:bg-indigo-400 text-white font-semibold rounded-xl transition-all flex items-center justify-center gap-2 text-xs cursor-pointer shadow-md shadow-indigo-600/10"
                >
                  {adding ? <Loader2 className="animate-spin" size={14} /> : <FolderPlus size={14} />}
                  Create
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modern Pop-up Edit Modal Dialog */}
      {editingCategory && (
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-xs z-50 flex items-center justify-center p-4 animate-in fade-in duration-200">
          <div className="bg-white rounded-2xl max-w-md w-full md:max-w-lg border border-slate-100 shadow-2xl overflow-hidden animate-in zoom-in-95 duration-200">
            {/* Modal Header */}
            <div className="flex justify-between items-center px-6 py-4.5 border-b border-slate-100 bg-slate-50/50">
              <h3 className="font-semibold text-slate-900 text-base">
                Edit Category
              </h3>
              <button 
                type="button" 
                onClick={() => { setEditingCategory(null); setEditImageFile(null); setEditImagePreview(null); setEditImageUrlInput(''); setEditName(''); }}
                className="p-1 hover:bg-slate-100 text-slate-400 hover:text-slate-600 rounded-lg transition-colors cursor-pointer"
              >
                <X size={18} />
              </button>
            </div>

            {/* Modal Form */}
            <form onSubmit={handleSaveEdit} className="p-6 space-y-5">
              {/* Category Name */}
              <div className="space-y-2">
                <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider pl-1">Category Name</label>
                <div className="relative">
                  <FolderPlus className="absolute left-3.5 top-3.5 h-4.5 w-4.5 text-slate-400" />
                  <input
                    type="text"
                    required
                    value={editName}
                    onChange={(e) => setEditName(e.target.value)}
                    placeholder="Category Name"
                    className="w-full pl-11 pr-4 py-3 bg-white border border-slate-200 rounded-xl text-slate-800 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-sm placeholder-slate-400 font-normal"
                  />
                </div>
              </div>

              {/* Image Upload Area */}
              <div className="space-y-2">
                <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider pl-1">Category Icon / Image</label>
                <div className="relative border border-dashed border-slate-200 hover:border-indigo-500 rounded-xl h-40 flex flex-col items-center justify-center bg-slate-50/50 hover:bg-white transition-all group cursor-pointer overflow-hidden">
                  {editImagePreview ? (
                    <>
                      <img src={editImagePreview} alt="Preview" className="w-full h-full object-cover animate-in fade-in duration-300" />
                      <div className="absolute inset-0 bg-slate-900/40 opacity-0 group-hover:opacity-100 flex flex-col items-center justify-center text-white transition-all duration-200">
                        <Upload className="h-6 w-6 mb-1 text-white animate-bounce" />
                        <span className="text-xs font-semibold">Change Image</span>
                      </div>
                    </>
                  ) : (
                    <div className="flex flex-col items-center text-center p-4">
                      <Upload className="h-6 w-6 text-slate-400 group-hover:text-indigo-600 transition-colors mb-2" />
                      <span className="text-slate-600 text-xs font-medium">Click to upload icon</span>
                      <span className="text-slate-400 text-[10px] mt-0.5 font-normal">PNG or JPG up to 2MB</span>
                    </div>
                  )}
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleEditImageChange}
                    className="absolute inset-0 opacity-0 cursor-pointer"
                  />
                </div>
                <div>
                  <input
                    type="url"
                    placeholder="Or paste Category Image URL"
                    value={editImageUrlInput}
                    onChange={handleEditUrlChange}
                    className="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-slate-800 focus:ring-2 focus:ring-indigo-600/10 focus:border-indigo-600 focus:outline-none transition-all text-xs placeholder-slate-400 font-normal mt-2"
                  />
                </div>
                <p className="text-[11px] text-slate-400 text-center font-normal">Hover or click on the image box to choose a new one, or paste a URL above.</p>
              </div>

              {/* Action Buttons */}
              <div className="flex gap-3 pt-4 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => { setEditingCategory(null); setEditImageFile(null); setEditImagePreview(null); setEditImageUrlInput(''); setEditName(''); }}
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

export default CategoryManager;
