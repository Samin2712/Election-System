import { useState, useRef } from 'react';
import { Upload, FileText, X, CheckCircle, AlertCircle, Mail, Users, Clock, Loader, Download } from 'lucide-react';
import toast from 'react-hot-toast';
import { invitationsApi } from '@/lib/api';
import type { BulkUploadResult } from '@/types';

interface CSVUploadModalProps {
    isOpen: boolean;
    onClose: () => void;
    organizationId: number;
    organizationName: string;
    onSuccess?: () => void;
}

export default function CSVUploadModal({
    isOpen,
    onClose,
    organizationId,
    organizationName,
    onSuccess,
}: CSVUploadModalProps) {
    const fileInputRef = useRef<HTMLInputElement>(null);
    const [file, setFile] = useState<File | null>(null);
    const [uploading, setUploading] = useState(false);
    const [result, setResult] = useState<BulkUploadResult | null>(null);
    const [options, setOptions] = useState({
        role_name: 'MEMBER',
        days_valid: 7,
        send_emails: true,
    });

    const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
        const selectedFile = e.target.files?.[0];
        if (selectedFile) {
            if (!selectedFile.name.endsWith('.csv')) {
                toast.error('Please select a CSV file');
                return;
            }
            if (selectedFile.size > 5 * 1024 * 1024) {
                toast.error('File size must be less than 5MB');
                return;
            }
            setFile(selectedFile);
            setResult(null);
        }
    };

    const handleDrop = (e: React.DragEvent<HTMLDivElement>) => {
        e.preventDefault();
        const droppedFile = e.dataTransfer.files[0];
        if (droppedFile) {
            if (!droppedFile.name.endsWith('.csv')) {
                toast.error('Please drop a CSV file');
                return;
            }
            if (droppedFile.size > 5 * 1024 * 1024) {
                toast.error('File size must be less than 5MB');
                return;
            }
            setFile(droppedFile);
            setResult(null);
        }
    };

    const handleUpload = async () => {
        if (!file) {
            toast.error('Please select a file first');
            return;
        }

        setUploading(true);
        try {
            const response = await invitationsApi.bulkUpload(organizationId, file, options);
            setResult(response);
            
            if (response.summary.successful > 0) {
                toast.success(`Successfully invited ${response.summary.successful} members!`);
                onSuccess?.();
            }
            if (response.summary.failed > 0) {
                toast.error(`${response.summary.failed} invitations failed`);
            }
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Upload failed');
        } finally {
            setUploading(false);
        }
    };

    const handleReset = () => {
        setFile(null);
        setResult(null);
        if (fileInputRef.current) {
            fileInputRef.current.value = '';
        }
    };

    const downloadTemplate = () => {
        const csv = 'email\nexample1@email.com\nexample2@email.com\nexample3@email.com';
        const blob = new Blob([csv], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'invitation_template.csv';
        a.click();
        window.URL.revokeObjectURL(url);
    };

    if (!isOpen) return null;

    return (
        <div className="modal-overlay" onClick={onClose}>
            <div className="modal-content max-w-2xl p-8" onClick={(e) => e.stopPropagation()}>
                {/* Header */}
                <div className="flex items-center justify-between mb-6">
                    <div>
                        <h2 className="text-2xl font-bold text-slate-900">Bulk Invite Members</h2>
                        <p className="text-slate-600 mt-1">
                            Upload a CSV file to invite multiple members to <span className="font-semibold">{organizationName}</span>
                        </p>
                    </div>
                    <button
                        onClick={onClose}
                        className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
                    >
                        <X className="w-6 h-6" />
                    </button>
                </div>

                {/* File Upload Area */}
                {!result && (
                    <>
                        <div
                            onDrop={handleDrop}
                            onDragOver={(e) => e.preventDefault()}
                            className={`border-2 border-dashed rounded-xl p-8 text-center transition-colors ${
                                file 
                                    ? 'border-green-400 bg-green-50' 
                                    : 'border-slate-300 hover:border-blue-400 hover:bg-blue-50'
                            }`}
                        >
                            {file ? (
                                <div className="flex items-center justify-center space-x-4">
                                    <div className="p-3 bg-green-100 rounded-xl">
                                        <FileText className="w-8 h-8 text-green-600" />
                                    </div>
                                    <div className="text-left">
                                        <p className="font-semibold text-slate-900">{file.name}</p>
                                        <p className="text-sm text-slate-600">
                                            {(file.size / 1024).toFixed(1)} KB
                                        </p>
                                    </div>
                                    <button
                                        onClick={handleReset}
                                        className="p-2 hover:bg-red-100 rounded-lg text-red-600"
                                    >
                                        <X className="w-5 h-5" />
                                    </button>
                                </div>
                            ) : (
                                <>
                                    <div className="p-4 bg-slate-100 rounded-full inline-block mb-4">
                                        <Upload className="w-8 h-8 text-slate-600" />
                                    </div>
                                    <p className="text-lg font-medium text-slate-900 mb-2">
                                        Drop your CSV file here
                                    </p>
                                    <p className="text-slate-600 mb-4">or</p>
                                    <button
                                        onClick={() => fileInputRef.current?.click()}
                                        className="btn-primary"
                                    >
                                        Browse Files
                                    </button>
                                    <input
                                        ref={fileInputRef}
                                        type="file"
                                        accept=".csv"
                                        onChange={handleFileSelect}
                                        className="hidden"
                                    />
                                </>
                            )}
                        </div>

                        {/* Template Download */}
                        <div className="mt-4 flex items-center justify-between p-4 bg-slate-50 rounded-xl">
                            <div className="flex items-center space-x-3">
                                <FileText className="w-5 h-5 text-slate-600" />
                                <div>
                                    <p className="font-medium text-slate-900">Need a template?</p>
                                    <p className="text-sm text-slate-600">CSV must have an "email" column</p>
                                </div>
                            </div>
                            <button
                                onClick={downloadTemplate}
                                className="flex items-center space-x-2 text-blue-600 hover:text-blue-700 font-medium"
                            >
                                <Download className="w-4 h-4" />
                                <span>Download Template</span>
                            </button>
                        </div>

                        {/* Options */}
                        <div className="mt-6 space-y-4">
                            <h3 className="font-semibold text-slate-900">Invitation Options</h3>
                            
                            <div className="grid grid-cols-2 gap-4">
                                <div className="form-group">
                                    <label className="label flex items-center space-x-2">
                                        <Users className="w-4 h-4" />
                                        <span>Role</span>
                                    </label>
                                    <select
                                        value={options.role_name}
                                        onChange={(e) => setOptions({ ...options, role_name: e.target.value })}
                                        className="input"
                                    >
                                        <option value="MEMBER">Member</option>
                                        <option value="ADMIN">Admin</option>
                                    </select>
                                </div>

                                <div className="form-group">
                                    <label className="label flex items-center space-x-2">
                                        <Clock className="w-4 h-4" />
                                        <span>Expires In</span>
                                    </label>
                                    <select
                                        value={options.days_valid}
                                        onChange={(e) => setOptions({ ...options, days_valid: parseInt(e.target.value) })}
                                        className="input"
                                    >
                                        <option value={1}>1 Day</option>
                                        <option value={3}>3 Days</option>
                                        <option value={7}>7 Days</option>
                                        <option value={14}>14 Days</option>
                                        <option value={30}>30 Days</option>
                                    </select>
                                </div>
                            </div>

                            <label className="flex items-center space-x-3 cursor-pointer">
                                <input
                                    type="checkbox"
                                    checked={options.send_emails}
                                    onChange={(e) => setOptions({ ...options, send_emails: e.target.checked })}
                                    className="w-5 h-5 rounded border-slate-300 text-blue-600 focus:ring-blue-500"
                                />
                                <div className="flex items-center space-x-2">
                                    <Mail className="w-4 h-4 text-slate-600" />
                                    <span className="text-slate-900">Send invitation emails</span>
                                </div>
                            </label>
                        </div>

                        {/* Upload Button */}
                        <div className="mt-8 flex justify-end space-x-4">
                            <button onClick={onClose} className="btn-secondary">
                                Cancel
                            </button>
                            <button
                                onClick={handleUpload}
                                disabled={!file || uploading}
                                className="btn-primary flex items-center space-x-2"
                            >
                                {uploading ? (
                                    <>
                                        <Loader className="w-5 h-5 animate-spin" />
                                        <span>Processing...</span>
                                    </>
                                ) : (
                                    <>
                                        <Upload className="w-5 h-5" />
                                        <span>Upload & Invite</span>
                                    </>
                                )}
                            </button>
                        </div>
                    </>
                )}

                {/* Results */}
                {result && (
                    <div className="space-y-6">
                        {/* Summary Card */}
                        <div className="grid grid-cols-3 gap-4">
                            <div className="p-4 bg-green-50 rounded-xl text-center">
                                <CheckCircle className="w-8 h-8 text-green-600 mx-auto mb-2" />
                                <p className="text-2xl font-bold text-green-700">{result.summary.successful}</p>
                                <p className="text-sm text-green-600">Successful</p>
                            </div>
                            <div className="p-4 bg-red-50 rounded-xl text-center">
                                <AlertCircle className="w-8 h-8 text-red-600 mx-auto mb-2" />
                                <p className="text-2xl font-bold text-red-700">{result.summary.failed}</p>
                                <p className="text-sm text-red-600">Failed</p>
                            </div>
                            <div className="p-4 bg-blue-50 rounded-xl text-center">
                                <Mail className="w-8 h-8 text-blue-600 mx-auto mb-2" />
                                <p className="text-2xl font-bold text-blue-700">{result.summary.emails_sent}</p>
                                <p className="text-sm text-blue-600">Emails Sent</p>
                            </div>
                        </div>

                        {/* Results List */}
                        <div className="max-h-64 overflow-y-auto border rounded-xl">
                            <table className="w-full">
                                <thead className="bg-slate-50 sticky top-0">
                                    <tr>
                                        <th className="px-4 py-3 text-left text-sm font-semibold text-slate-600">Email</th>
                                        <th className="px-4 py-3 text-left text-sm font-semibold text-slate-600">Status</th>
                                        <th className="px-4 py-3 text-left text-sm font-semibold text-slate-600">Message</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-slate-100">
                                    {result.results.map((item, index) => (
                                        <tr key={index} className="hover:bg-slate-50">
                                            <td className="px-4 py-3 text-sm text-slate-900">{item.email}</td>
                                            <td className="px-4 py-3">
                                                <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${
                                                    item.status === 'SUCCESS' 
                                                        ? 'bg-green-100 text-green-700'
                                                        : item.status === 'SKIPPED'
                                                        ? 'bg-yellow-100 text-yellow-700'
                                                        : 'bg-red-100 text-red-700'
                                                }`}>
                                                    {item.status}
                                                </span>
                                            </td>
                                            <td className="px-4 py-3 text-sm text-slate-600">{item.message}</td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>

                        {/* Invalid Emails Warning */}
                        {result.invalidEmails && result.invalidEmails.length > 0 && (
                            <div className="p-4 bg-yellow-50 border border-yellow-200 rounded-xl">
                                <div className="flex items-start space-x-3">
                                    <AlertCircle className="w-5 h-5 text-yellow-600 mt-0.5" />
                                    <div>
                                        <p className="font-medium text-yellow-800">
                                            {result.invalidEmails.length} invalid email(s) were skipped:
                                        </p>
                                        <p className="text-sm text-yellow-700 mt-1">
                                            {result.invalidEmails.slice(0, 5).join(', ')}
                                            {result.invalidEmails.length > 5 && ` and ${result.invalidEmails.length - 5} more...`}
                                        </p>
                                    </div>
                                </div>
                            </div>
                        )}

                        {/* Actions */}
                        <div className="flex justify-end space-x-4">
                            <button onClick={handleReset} className="btn-secondary">
                                Upload Another
                            </button>
                            <button onClick={onClose} className="btn-primary">
                                Done
                            </button>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}
