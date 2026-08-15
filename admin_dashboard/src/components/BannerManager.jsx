import React, { useState, useEffect, useRef } from 'react';
import { api } from '../apiClient';
import { uploadImage, deleteImage } from '../imageUpload';
import {
  ImagePlus, Trash2, Loader2, CheckCircle2, Upload,
  Star, AlertCircle, X
} from 'lucide-react';

const PLACEMENTS = [
  { value: 'hero', label: 'Top Hero Carousel' },
  { value: 'category', label: 'Above Category' },
];

const BannerManager = () => {
  const [banners, setBanners] = useState([]);
  const [activePlacement, setActivePlacement] = useState('hero');
  const [uploadPlacement, setUploadPlacement] = useState('hero');

  const [imageFile, setImageFile] = useState(null);
  const [imagePreview, setImagePreview] = useState(null);

  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [deletingId, setDeletingId] = useState(null);

  const [toast, setToast] = useState(null);
  const fileInputRef = useRef(null);

  const showToast = (type, message) => {
    setToast({ type, message });
    setTimeout(() => setToast(null), 4000);
  };

  // ── Fetch banners ─────────────────────────────────────────────────────────
  const fetchBanners = async () => {
    setLoading(true);
    try {
      const { banners: data } = await api.get('/banners');
      setBanners((data || []).slice().sort((a, b) => new Date(a.created_at) - new Date(b.created_at)));
    } catch (err) {
      showToast('error', 'Failed to load banners: ' + err.message);
    }
    setLoading(false);
  };

  useEffect(() => { fetchBanners(); }, []);

  // ── Image Selection ────────────────────────────────────────────────────────
  const handleImageChange = (e) => {
    const file = e.target.files[0];
    if (!file) return;
    setImageFile(file);
    setImagePreview(URL.createObjectURL(file));
  };

  const clearUploadForm = () => {
    setImageFile(null);
    setImagePreview(null);
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  // ── Upload to Cloudinary + save banner record ────────────────────────────
  const handleUpload = async () => {
    if (!imageFile) return;
    setUploading(true);
    try {
      const publicUrl = await uploadImage(imageFile, 'banners');
      await api.post('/banners', { image_url: publicUrl, placement: uploadPlacement });

      clearUploadForm();
      setActivePlacement(uploadPlacement);
      await fetchBanners();
      showToast('success', 'Banner saved!');
    } catch (err) {
      console.error('Upload error:', err);
      showToast('error', err.message || 'Upload failed');
    }
    setUploading(false);
  };

  // ── Delete banner record + Cloudinary image ──────────────────────────────
  const handleDelete = async (banner) => {
    if (!window.confirm('Delete this banner permanently? This will remove the image file from storage.')) return;
    setDeletingId(banner.id);
    try {
      await api.delete(`/banners/${banner.id}`);
      await deleteImage(banner.image_url);

      await fetchBanners();
      showToast('success', 'Banner deleted.');
    } catch (err) {
      console.error('Delete error:', err);
      showToast('error', `Delete failed: ${err.message || 'Unknown error'}`);
    }
    setDeletingId(null);
  };

  // ── Derived ────────────────────────────────────────────────────────────────
  const filteredBanners = banners.filter(b => (b.placement || 'hero') === activePlacement);
  const mainBannerId = filteredBanners.length > 0 ? filteredBanners[0].id : null;
  const countFor = (p) => banners.filter(b => (b.placement || 'hero') === p).length;

  return (
    <div className="w-full max-w-5xl space-y-8 font-sans">
      {/* Header */}
      <div className="pb-5 border-b border-slate-100">
        <h2 className="text-xl font-bold text-slate-900 tracking-tight">Home Page Banners</h2>
        <p className="text-slate-500 text-sm mt-1">
          Images are stored in <strong>Cloudinary</strong>. The <span className="text-amber-500 font-semibold">★ first</span> banner per placement is the <strong>Main</strong> banner shown in the app.
        </p>
      </div>

      {/* Toast */}
      {toast && (
        <div className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium border ${
          toast.type === 'success'
            ? 'bg-emerald-50 text-emerald-700 border-emerald-100'
            : 'bg-rose-50 text-rose-700 border-rose-100'
        }`}>
          {toast.type === 'success' ? <CheckCircle2 size={16} /> : <AlertCircle size={16} />}
          <span className="flex-1">{toast.message}</span>
          <button onClick={() => setToast(null)} className="cursor-pointer opacity-60 hover:opacity-100">
            <X size={14} />
          </button>
        </div>
      )}

      {/* ── Upload Panel ── */}
      <div className="bg-white rounded-2xl border border-slate-200 p-6 space-y-5 shadow-sm">
        <h3 className="text-sm font-semibold text-slate-700 flex items-center gap-2">
          <ImagePlus size={16} className="text-indigo-500" />
          Upload New Banner
          <span className="ml-auto text-[11px] font-normal text-slate-400 bg-slate-100 px-2 py-1 rounded-full">
            Stored in Cloudinary
          </span>
        </h3>

        {/* Placement Selector */}
        <div>
          <label className="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2">
            Banner Placement
          </label>
          <div className="grid grid-cols-2 gap-2 rounded-xl bg-slate-50 p-1 border border-slate-100">
            {PLACEMENTS.map(opt => (
              <button
                key={opt.value}
                type="button"
                onClick={() => setUploadPlacement(opt.value)}
                className={`py-2.5 px-3 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                  uploadPlacement === opt.value
                    ? 'bg-white text-indigo-600 shadow-sm'
                    : 'text-slate-500 hover:text-slate-800'
                }`}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>

        {/* Drop Zone */}
        <div
          className="relative border-2 border-dashed border-slate-200 rounded-2xl h-52 flex flex-col items-center justify-center bg-slate-50/50 hover:bg-white hover:border-indigo-400 transition-all group cursor-pointer overflow-hidden"
          onClick={() => fileInputRef.current?.click()}
        >
          {imagePreview ? (
            <>
              <img src={imagePreview} alt="Preview" className="w-full h-full object-cover" />
              <button
                type="button"
                onClick={e => { e.stopPropagation(); clearUploadForm(); }}
                className="absolute top-2 right-2 bg-white/90 hover:bg-white text-slate-600 rounded-full p-1.5 shadow-md transition-all cursor-pointer"
              >
                <X size={14} />
              </button>
              <div className="absolute bottom-2 left-1/2 -translate-x-1/2 bg-black/50 text-white text-xs font-medium px-3 py-1 rounded-full pointer-events-none">
                Click to change image
              </div>
            </>
          ) : (
            <div className="flex flex-col items-center gap-3 text-slate-400 group-hover:text-indigo-500 transition-colors pointer-events-none">
              <Upload size={30} />
              <div className="text-center">
                <p className="font-semibold text-sm text-slate-600">Click to choose a banner image</p>
                <p className="text-xs text-slate-400 mt-0.5">PNG, JPG, WEBP · Recommended: 1600 × 900</p>
              </div>
            </div>
          )}
          <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={handleImageChange} />
        </div>

        {/* Buttons */}
        <div className="flex gap-3">
          <button
            type="button"
            onClick={clearUploadForm}
            disabled={!imageFile || uploading}
            className="flex-1 py-3 bg-slate-100 hover:bg-slate-200 disabled:opacity-40 text-slate-700 font-semibold rounded-xl transition-all text-sm cursor-pointer"
          >
            Clear
          </button>
          <button
            type="button"
            onClick={handleUpload}
            disabled={uploading || !imageFile}
            className="flex-[3] py-3 bg-indigo-600 hover:bg-indigo-700 disabled:bg-indigo-300 text-white font-semibold rounded-xl shadow-md shadow-indigo-200 transition-all flex items-center justify-center gap-2 text-sm cursor-pointer"
          >
            {uploading ? <Loader2 className="animate-spin" size={16} /> : <ImagePlus size={16} />}
            {uploading ? 'Uploading…' : 'Save Banner'}
          </button>
        </div>
      </div>

      {/* ── Banners List ── */}
      <div className="space-y-4">
        <div className="flex flex-wrap items-center gap-2">
          {PLACEMENTS.map(opt => (
            <button
              key={opt.value}
              type="button"
              onClick={() => setActivePlacement(opt.value)}
              className={`px-4 py-2 rounded-lg text-xs font-semibold transition-all cursor-pointer flex items-center gap-2 ${
                activePlacement === opt.value
                  ? 'bg-indigo-600 text-white shadow-sm'
                  : 'bg-slate-100 text-slate-500 hover:text-slate-800'
              }`}
            >
              {opt.label}
              <span className={`px-1.5 py-0.5 rounded-full text-[10px] font-bold ${
                activePlacement === opt.value ? 'bg-white/25 text-white' : 'bg-slate-200 text-slate-500'
              }`}>
                {countFor(opt.value)}
              </span>
            </button>
          ))}
        </div>

        {loading ? (
          <div className="flex flex-col items-center justify-center py-20 text-slate-400 gap-3">
            <Loader2 className="animate-spin text-indigo-500" size={28} />
            <p className="text-sm">Loading banners…</p>
          </div>
        ) : filteredBanners.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 bg-white rounded-2xl border border-dashed border-slate-200 text-slate-400 gap-2">
            <Upload size={28} />
            <p className="text-sm font-medium">No banners for this placement yet</p>
            <p className="text-xs">Upload one above and it will appear in the mobile app.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            {filteredBanners.map((banner) => {
              const isMain = banner.id === mainBannerId;
              return (
                <div
                  key={banner.id}
                  className={`relative bg-white rounded-2xl border-2 overflow-hidden shadow-sm transition-all ${
                    isMain ? 'border-amber-400 shadow-amber-100' : 'border-slate-100'
                  }`}
                >
                  {isMain && (
                    <div className="absolute top-3 left-3 z-10 flex items-center gap-1.5 bg-amber-400 text-white text-[11px] font-bold px-2.5 py-1 rounded-full shadow">
                      <Star size={10} fill="white" />
                      MAIN
                    </div>
                  )}
                  <div className="h-44 w-full overflow-hidden bg-slate-100">
                    <img
                      src={banner.image_url}
                      alt="Banner"
                      className="w-full h-full object-cover"
                      onError={e => { e.target.src = 'https://placehold.co/800x400/e2e8f0/94a3b8?text=Image+Error'; }}
                    />
                  </div>
                  <div className="px-4 py-3 flex items-center justify-between bg-white border-t border-slate-50">
                    <div>
                      <p className="text-xs text-slate-400">
                        Added {new Date(banner.created_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })}
                      </p>
                      {isMain && <p className="text-[11px] text-amber-500 font-semibold mt-0.5">Shown first in the app</p>}
                    </div>
                    <button
                      onClick={() => handleDelete(banner)}
                      disabled={deletingId === banner.id}
                      className="flex items-center gap-1.5 px-3 py-2 bg-rose-50 hover:bg-rose-100 text-rose-500 hover:text-rose-700 rounded-lg text-xs font-semibold transition-all cursor-pointer disabled:opacity-50"
                    >
                      {deletingId === banner.id ? <Loader2 size={13} className="animate-spin" /> : <Trash2 size={13} />}
                      {deletingId === banner.id ? 'Deleting…' : 'Delete'}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

export default BannerManager;
