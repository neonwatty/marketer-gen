import React, { useState, useCallback, useEffect } from 'react'
import { useDropzone } from 'react-dropzone'
import ReactCrop, { Crop, PixelCrop } from 'react-image-crop'
import 'react-image-crop/dist/ReactCrop.css'

interface MediaFile {
  id: string
  name: string
  type: 'image' | 'video' | 'document'
  url: string
  thumbnail?: string
  size: number
  format: string
  dimensions?: {
    width: number
    height: number
  }
  uploadedAt: Date
  tags: string[]
  brandAsset?: boolean
}

interface MediaManagerProps {
  onSelect?: (file: MediaFile) => void
  onUpload?: (files: File[]) => Promise<MediaFile[]>
  allowedTypes?: ('image' | 'video' | 'document')[]
  multiple?: boolean
  showBrandAssets?: boolean
  className?: string
  maxFileSize?: number
  enableCropping?: boolean
  enableBatchUpload?: boolean
}

export const MediaManager: React.FC<MediaManagerProps> = ({
  onSelect,
  onUpload,
  allowedTypes = ['image', 'video', 'document'],
  multiple = true,
  showBrandAssets = true,
  className = '',
  maxFileSize = 10 * 1024 * 1024, // 10MB
  enableCropping = true,
  enableBatchUpload = true
}) => {
  const [files, setFiles] = useState<MediaFile[]>([])
  const [filteredFiles, setFilteredFiles] = useState<MediaFile[]>([])
  const [selectedFiles, setSelectedFiles] = useState<string[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [filterType, setFilterType] = useState<'all' | 'image' | 'video' | 'document' | 'brand'>('all')
  const [sortBy, setSortBy] = useState<'date' | 'name' | 'size'>('date')
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid')
  const [uploading, setUploading] = useState(false)
  const [uploadProgress, setUploadProgress] = useState<{ [key: string]: number }>({})
  const [showCropper, setShowCropper] = useState(false)
  const [cropImage, setCropImage] = useState<MediaFile | null>(null)
  const [crop, setCrop] = useState<Crop>()
  const [completedCrop, setCompletedCrop] = useState<PixelCrop>()

  // Mock data - in real app, this would come from an API
  useEffect(() => {
    const mockFiles: MediaFile[] = [
      {
        id: '1',
        name: 'brand-logo.png',
        type: 'image',
        url: '/images/brand-logo.png',
        thumbnail: '/images/brand-logo-thumb.png',
        size: 45678,
        format: 'PNG',
        dimensions: { width: 400, height: 200 },
        uploadedAt: new Date('2024-01-15'),
        tags: ['logo', 'brand', 'header'],
        brandAsset: true
      },
      {
        id: '2',
        name: 'product-demo.mp4',
        type: 'video',
        url: '/videos/product-demo.mp4',
        thumbnail: '/images/video-thumb.jpg',
        size: 2456789,
        format: 'MP4',
        dimensions: { width: 1920, height: 1080 },
        uploadedAt: new Date('2024-01-10'),
        tags: ['demo', 'product', 'marketing']
      },
      {
        id: '3',
        name: 'brand-guidelines.pdf',
        type: 'document',
        url: '/docs/brand-guidelines.pdf',
        size: 1234567,
        format: 'PDF',
        uploadedAt: new Date('2024-01-05'),
        tags: ['guidelines', 'brand', 'documentation'],
        brandAsset: true
      }
    ]
    setFiles(mockFiles)
  }, [])

  // Filter and sort files
  useEffect(() => {
    let filtered = files

    // Filter by type
    if (filterType !== 'all') {
      if (filterType === 'brand') {
        filtered = filtered.filter(file => file.brandAsset)
      } else {
        filtered = filtered.filter(file => file.type === filterType)
      }
    }

    // Filter by search query
    if (searchQuery) {
      const query = searchQuery.toLowerCase()
      filtered = filtered.filter(file => 
        file.name.toLowerCase().includes(query) ||
        file.tags.some(tag => tag.toLowerCase().includes(query))
      )
    }

    // Sort files
    filtered.sort((a, b) => {
      switch (sortBy) {
        case 'name':
          return a.name.localeCompare(b.name)
        case 'size':
          return b.size - a.size
        case 'date':
        default:
          return b.uploadedAt.getTime() - a.uploadedAt.getTime()
      }
    })

    setFilteredFiles(filtered)
  }, [files, filterType, searchQuery, sortBy])

  const onDrop = useCallback(async (acceptedFiles: File[]) => {
    if (!onUpload || !enableBatchUpload) {return}

    setUploading(true)
    const progressMap: { [key: string]: number } = {}

    // Initialize progress for each file
    acceptedFiles.forEach(file => {
      progressMap[file.name] = 0
    })
    setUploadProgress(progressMap)

    try {
      // Simulate upload progress
      const uploadPromises = acceptedFiles.map(async (file, index) => {
        return new Promise<void>((resolve) => {
          const interval = setInterval(() => {
            progressMap[file.name] += Math.random() * 30
            if (progressMap[file.name] >= 100) {
              progressMap[file.name] = 100
              clearInterval(interval)
              resolve()
            }
            setUploadProgress({ ...progressMap })
          }, 100)
        })
      })

      await Promise.all(uploadPromises)

      // Upload files
      const uploadedFiles = await onUpload(acceptedFiles)
      setFiles(prev => [...prev, ...uploadedFiles])

    } catch (error) {
      console.error('Upload failed:', error)
    } finally {
      setUploading(false)
      setUploadProgress({})
    }
  }, [onUpload, enableBatchUpload])

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'image/*': allowedTypes.includes('image') ? ['.jpeg', '.jpg', '.png', '.gif', '.webp'] : [],
      'video/*': allowedTypes.includes('video') ? ['.mp4', '.mov', '.avi', '.webm'] : [],
      'application/pdf': allowedTypes.includes('document') ? ['.pdf'] : [],
    },
    multiple: enableBatchUpload ? multiple : false,
    maxSize: maxFileSize,
  })

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) {return '0 Bytes'}
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))  } ${  sizes[i]}`
  }

  const handleFileSelect = (file: MediaFile) => {
    if (multiple) {
      setSelectedFiles(prev => 
        prev.includes(file.id) 
          ? prev.filter(id => id !== file.id)
          : [...prev, file.id]
      )
    } else {
      onSelect?.(file)
    }
  }

  const handleCropImage = (file: MediaFile) => {
    setCropImage(file)
    setShowCropper(true)
  }

  const getFileIcon = (file: MediaFile) => {
    switch (file.type) {
      case 'image':
        return '🖼️'
      case 'video':
        return '🎥'
      case 'document':
        return '📄'
      default:
        return '📁'
    }
  }

  const renderGridView = () => (
    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
      {filteredFiles.map((file) => (
        <div
          key={file.id}
          className={`relative group cursor-pointer rounded-lg border-2 overflow-hidden transition-all duration-200 ${
            selectedFiles.includes(file.id)
              ? 'border-blue-500 shadow-lg'
              : 'border-gray-200 hover:border-gray-300 hover:shadow-md'
          }`}
          onClick={() => handleFileSelect(file)}
        >
          {/* File Preview */}
          <div className="aspect-square bg-gray-100 flex items-center justify-center overflow-hidden">
            {file.type === 'image' ? (
              <img
                src={file.thumbnail || file.url}
                alt={file.name}
                className="w-full h-full object-cover"
              />
            ) : (
              <div className="text-4xl">
                {getFileIcon(file)}
              </div>
            )}
          </div>

          {/* File Info Overlay */}
          <div className="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-50 transition-all duration-200 flex items-end">
            <div className="w-full p-2 text-white opacity-0 group-hover:opacity-100 transition-opacity duration-200">
              <p className="text-xs font-medium truncate">{file.name}</p>
              <p className="text-xs text-gray-300">
                {formatFileSize(file.size)} • {file.format}
              </p>
            </div>
          </div>

          {/* Brand Asset Badge */}
          {file.brandAsset && (
            <div className="absolute top-2 right-2 bg-blue-600 text-white text-xs px-2 py-1 rounded-full">
              Brand
            </div>
          )}

          {/* Selection Indicator */}
          {selectedFiles.includes(file.id) && (
            <div className="absolute top-2 left-2 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center">
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>
          )}

          {/* Action Buttons */}
          <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity duration-200 flex space-x-1">
            {file.type === 'image' && enableCropping && (
              <button
                onClick={(e) => {
                  e.stopPropagation()
                  handleCropImage(file)
                }}
                className="p-1 bg-white text-gray-600 rounded hover:bg-gray-100"
                title="Crop image"
              >
                <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
              </button>
            )}
          </div>
        </div>
      ))}
    </div>
  )

  const renderListView = () => (
    <div className="space-y-2">
      {filteredFiles.map((file) => (
        <div
          key={file.id}
          className={`flex items-center p-3 rounded-lg border cursor-pointer transition-colors ${
            selectedFiles.includes(file.id)
              ? 'border-blue-500 bg-blue-50'
              : 'border-gray-200 hover:bg-gray-50'
          }`}
          onClick={() => handleFileSelect(file)}
        >
          {/* File Preview */}
          <div className="w-12 h-12 bg-gray-100 rounded flex items-center justify-center flex-shrink-0 mr-4">
            {file.type === 'image' ? (
              <img
                src={file.thumbnail || file.url}
                alt={file.name}
                className="w-full h-full object-cover rounded"
              />
            ) : (
              <span className="text-xl">{getFileIcon(file)}</span>
            )}
          </div>

          {/* File Info */}
          <div className="flex-1 min-w-0">
            <div className="flex items-center space-x-2">
              <p className="text-sm font-medium text-gray-900 truncate">{file.name}</p>
              {file.brandAsset && (
                <span className="inline-flex items-center px-2 py-1 rounded-full text-xs bg-blue-100 text-blue-800">
                  Brand
                </span>
              )}
            </div>
            <div className="flex items-center space-x-4 text-xs text-gray-500 mt-1">
              <span>{file.format}</span>
              <span>{formatFileSize(file.size)}</span>
              {file.dimensions && (
                <span>{file.dimensions.width}×{file.dimensions.height}</span>
              )}
              <span>{file.uploadedAt.toLocaleDateString()}</span>
            </div>
            {file.tags.length > 0 && (
              <div className="flex flex-wrap gap-1 mt-2">
                {file.tags.map((tag, index) => (
                  <span key={index} className="inline-flex items-center px-2 py-1 rounded-full text-xs bg-gray-100 text-gray-800">
                    {tag}
                  </span>
                ))}
              </div>
            )}
          </div>

          {/* Actions */}
          <div className="flex items-center space-x-2 ml-4">
            {file.type === 'image' && enableCropping && (
              <button
                onClick={(e) => {
                  e.stopPropagation()
                  handleCropImage(file)
                }}
                className="p-2 text-gray-400 hover:text-gray-600"
                title="Crop image"
              >
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
              </button>
            )}
          </div>
        </div>
      ))}
    </div>
  )

  return (
    <div className={`media-manager bg-white border border-gray-300 rounded-lg ${className}`}>
      {/* Header */}
      <div className="p-4 border-b border-gray-200">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between space-y-3 sm:space-y-0">
          <h3 className="text-lg font-semibold text-gray-900">Media Library</h3>
          
          {/* View Controls */}
          <div className="flex items-center space-x-3">
            <div className="flex bg-gray-100 rounded-lg p-1">
              <button
                onClick={() => setViewMode('grid')}
                className={`p-2 rounded-md transition-colors ${
                  viewMode === 'grid' ? 'bg-white shadow-sm' : 'hover:bg-gray-200'
                }`}
                title="Grid view"
              >
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M5 3a2 2 0 00-2 2v2a2 2 0 002 2h2a2 2 0 002-2V5a2 2 0 00-2-2H5zM5 11a2 2 0 00-2 2v2a2 2 0 002 2h2a2 2 0 002-2v-2a2 2 0 00-2-2H5zM11 5a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V5zM11 13a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
                </svg>
              </button>
              <button
                onClick={() => setViewMode('list')}
                className={`p-2 rounded-md transition-colors ${
                  viewMode === 'list' ? 'bg-white shadow-sm' : 'hover:bg-gray-200'
                }`}
                title="List view"
              >
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clipRule="evenodd" />
                </svg>
              </button>
            </div>
          </div>
        </div>

        {/* Filters and Search */}
        <div className="flex flex-col sm:flex-row sm:items-center space-y-3 sm:space-y-0 sm:space-x-4 mt-4">
          {/* Search */}
          <div className="flex-1 relative">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <svg className="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
            <input
              type="text"
              placeholder="Search files..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
            />
          </div>

          {/* Type Filter */}
          <select
            value={filterType}
            onChange={(e) => setFilterType(e.target.value as any)}
            className="block pl-3 pr-10 py-2 text-base border border-gray-300 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm rounded-md"
          >
            <option value="all">All Files</option>
            {allowedTypes.includes('image') && <option value="image">Images</option>}
            {allowedTypes.includes('video') && <option value="video">Videos</option>}
            {allowedTypes.includes('document') && <option value="document">Documents</option>}
            {showBrandAssets && <option value="brand">Brand Assets</option>}
          </select>

          {/* Sort */}
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value as any)}
            className="block pl-3 pr-10 py-2 text-base border border-gray-300 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm rounded-md"
          >
            <option value="date">Date Added</option>
            <option value="name">Name</option>
            <option value="size">File Size</option>
          </select>
        </div>
      </div>

      {/* Upload Area */}
      {enableBatchUpload && (
        <div className="p-4 border-b border-gray-200">
          <div
            {...getRootProps()}
            className={`border-2 border-dashed rounded-lg p-6 text-center transition-colors cursor-pointer ${
              isDragActive
                ? 'border-blue-400 bg-blue-50'
                : 'border-gray-300 hover:border-gray-400'
            }`}
          >
            <input {...getInputProps()} />
            <svg className="mx-auto h-12 w-12 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
            </svg>
            {isDragActive ? (
              <p className="text-blue-600">Drop files here...</p>
            ) : (
              <>
                <p className="text-gray-600 mb-2">Drag & drop files here, or click to select</p>
                <p className="text-sm text-gray-500">
                  {allowedTypes.join(', ').toUpperCase()} files up to {formatFileSize(maxFileSize)}
                </p>
              </>
            )}
          </div>

          {/* Upload Progress */}
          {uploading && Object.keys(uploadProgress).length > 0 && (
            <div className="mt-4 space-y-2">
              {Object.entries(uploadProgress).map(([filename, progress]) => (
                <div key={filename} className="space-y-1">
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-600 truncate">{filename}</span>
                    <span className="text-gray-500">{Math.round(progress)}%</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <div 
                      className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                      style={{ width: `${progress}%` }}
                     />
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Files List */}
      <div className="p-4">
        {filteredFiles.length === 0 ? (
          <div className="text-center py-12">
            <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
            </svg>
            <h3 className="mt-2 text-sm font-medium text-gray-900">No files found</h3>
            <p className="mt-1 text-sm text-gray-500">
              {searchQuery ? 'Try adjusting your search or filters' : 'Upload some files to get started'}
            </p>
          </div>
        ) : (
          <>
            {viewMode === 'grid' ? renderGridView() : renderListView()}
            
            {/* Selection Actions */}
            {multiple && selectedFiles.length > 0 && (
              <div className="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-blue-800">
                    {selectedFiles.length} file{selectedFiles.length !== 1 ? 's' : ''} selected
                  </span>
                  <div className="flex space-x-2">
                    <button
                      onClick={() => setSelectedFiles([])}
                      className="text-sm text-blue-600 hover:text-blue-800"
                    >
                      Clear selection
                    </button>
                    <button
                      onClick={() => {
                        const selectedMedia = files.filter(f => selectedFiles.includes(f.id))
                        selectedMedia.forEach(file => onSelect?.(file))
                      }}
                      className="px-3 py-1 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 transition-colors"
                    >
                      Use Selected
                    </button>
                  </div>
                </div>
              </div>
            )}
          </>
        )}
      </div>

      {/* Crop Modal */}
      {showCropper && cropImage && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
          <div className="bg-white rounded-lg shadow-xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-hidden">
            <div className="flex items-center justify-between p-4 border-b border-gray-200">
              <h3 className="text-lg font-semibold text-gray-900">Crop Image</h3>
              <button
                onClick={() => setShowCropper(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            
            <div className="p-4 max-h-96 overflow-auto">
              <ReactCrop
                crop={crop}
                onChange={(c) => setCrop(c)}
                onComplete={(c) => setCompletedCrop(c)}
              >
                <img
                  src={cropImage.url}
                  alt={cropImage.name}
                  className="max-w-full h-auto"
                />
              </ReactCrop>
            </div>

            <div className="flex justify-end space-x-3 p-4 bg-gray-50 border-t border-gray-200">
              <button
                onClick={() => setShowCropper(false)}
                className="px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  // Handle crop save
                  setShowCropper(false)
                }}
                className="px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                Apply Crop
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default MediaManager