import React, { useState, useEffect, useRef, useCallback } from 'react'
import { Editor } from '@tiptap/react'
import { useDropzone } from 'react-dropzone'
import ReactCrop, { Crop, PixelCrop } from 'react-image-crop'
import 'react-image-crop/dist/ReactCrop.css'

interface ImageUploadModalProps {
  editor: Editor
  onClose: () => void
}

interface ImageFile {
  file: File
  preview: string
  id: string
}

export const ImageUploadModal: React.FC<ImageUploadModalProps> = ({ editor, onClose }) => {
  const [images, setImages] = useState<ImageFile[]>([])
  const [selectedImage, setSelectedImage] = useState<ImageFile | null>(null)
  const [imageUrl, setImageUrl] = useState('')
  const [altText, setAltText] = useState('')
  const [uploadMethod, setUploadMethod] = useState<'upload' | 'url' | 'library'>('upload')
  const [uploading, setUploading] = useState(false)
  const [crop, setCrop] = useState<Crop>()
  const [completedCrop, setCompletedCrop] = useState<PixelCrop>()
  const [showCropper, setShowCropper] = useState(false)
  const modalRef = useRef<HTMLDivElement>(null)
  const imageRef = useRef<HTMLImageElement>(null)

  // Close modal when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (modalRef.current && !modalRef.current.contains(event.target as Node)) {
        onClose()
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [onClose])

  // Close modal on Escape key
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose()
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => {
      document.removeEventListener('keydown', handleKeyDown)
    }
  }, [onClose])

  // Clean up object URLs
  useEffect(() => {
    return () => {
      images.forEach(image => URL.revokeObjectURL(image.preview))
    }
  }, [images])

  const onDrop = useCallback((acceptedFiles: File[]) => {
    const newImages = acceptedFiles.map(file => ({
      file,
      preview: URL.createObjectURL(file),
      id: Math.random().toString(36).substring(7)
    }))
    
    setImages(prev => [...prev, ...newImages])
  }, [])

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'image/*': ['.jpeg', '.jpg', '.png', '.gif', '.webp', '.svg']
    },
    multiple: true,
    maxSize: 10 * 1024 * 1024, // 10MB
  })

  const removeImage = (id: string) => {
    setImages(prev => {
      const imageToRemove = prev.find(img => img.id === id)
      if (imageToRemove) {
        URL.revokeObjectURL(imageToRemove.preview)
      }
      return prev.filter(img => img.id !== id)
    })
  }

  const handleImageLoad = (e: React.SyntheticEvent<HTMLImageElement>) => {
    const { width, height } = e.currentTarget
    setCrop({
      unit: '%',
      width: 100,
      height: 100,
      x: 0,
      y: 0
    })
  }

  const getCroppedImg = async (
    image: HTMLImageElement,
    crop: PixelCrop,
    fileName: string
  ): Promise<Blob> => {
    const canvas = document.createElement('canvas')
    const ctx = canvas.getContext('2d')

    if (!ctx) {
      throw new Error('No 2d context')
    }

    const scaleX = image.naturalWidth / image.width
    const scaleY = image.naturalHeight / image.height

    canvas.width = crop.width
    canvas.height = crop.height

    ctx.drawImage(
      image,
      crop.x * scaleX,
      crop.y * scaleY,
      crop.width * scaleX,
      crop.height * scaleY,
      0,
      0,
      crop.width,
      crop.height
    )

    return new Promise((resolve) => {
      canvas.toBlob((blob) => {
        if (blob) {
          resolve(blob)
        }
      }, 'image/jpeg', 0.95)
    })
  }

  const uploadImage = async (imageData: Blob | File, filename: string): Promise<string> => {
    const formData = new FormData()
    formData.append('image', imageData, filename)
    formData.append('alt_text', altText)

    try {
      const response = await fetch('/api/v1/media/upload', {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || ''
        }
      })

      if (!response.ok) {
        throw new Error('Upload failed')
      }

      const data = await response.json()
      return data.url
    } catch (error) {
      console.error('Upload error:', error)
      throw error
    }
  }

  const handleInsertImage = async () => {
    setUploading(true)

    try {
      let finalImageUrl = ''
      const finalAltText = altText

      if (uploadMethod === 'url') {
        finalImageUrl = imageUrl
      } else if (uploadMethod === 'upload' && selectedImage) {
        if (showCropper && completedCrop && imageRef.current) {
          // Upload cropped image
          const croppedBlob = await getCroppedImg(
            imageRef.current,
            completedCrop,
            selectedImage.file.name
          )
          finalImageUrl = await uploadImage(croppedBlob, selectedImage.file.name)
        } else {
          // Upload original image
          finalImageUrl = await uploadImage(selectedImage.file, selectedImage.file.name)
        }
      }

      if (finalImageUrl) {
        editor.chain().focus().setImage({
          src: finalImageUrl,
          alt: finalAltText || 'Image',
          title: finalAltText
        }).run()
        onClose()
      }
    } catch (error) {
      console.error('Error inserting image:', error)
      alert('Failed to insert image. Please try again.')
    } finally {
      setUploading(false)
    }
  }

  const validateImageUrl = (url: string) => {
    try {
      new URL(url)
      return url.match(/\.(jpeg|jpg|gif|png|webp|svg)(\?.*)?$/i) !== null
    } catch {
      return false
    }
  }

  const isValidUrl = validateImageUrl(imageUrl)
  const canInsert = uploadMethod === 'url' ? isValidUrl : selectedImage !== null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div
        ref={modalRef}
        className="bg-white rounded-lg shadow-xl border border-gray-200 max-w-4xl w-full mx-4 max-h-[90vh] overflow-hidden"
      >
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900">Insert Image</h3>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
            title="Close"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="flex flex-col lg:flex-row h-full">
          {/* Sidebar */}
          <div className="lg:w-1/3 p-6 border-r border-gray-200 overflow-y-auto">
            {/* Upload Method Tabs */}
            <div className="flex space-x-1 mb-6 bg-gray-100 p-1 rounded-lg">
              <button
                onClick={() => setUploadMethod('upload')}
                className={`flex-1 py-2 px-3 text-sm font-medium rounded-md transition-colors ${
                  uploadMethod === 'upload'
                    ? 'bg-white text-gray-900 shadow-sm'
                    : 'text-gray-500 hover:text-gray-700'
                }`}
              >
                Upload
              </button>
              <button
                onClick={() => setUploadMethod('url')}
                className={`flex-1 py-2 px-3 text-sm font-medium rounded-md transition-colors ${
                  uploadMethod === 'url'
                    ? 'bg-white text-gray-900 shadow-sm'
                    : 'text-gray-500 hover:text-gray-700'
                }`}
              >
                URL
              </button>
              <button
                onClick={() => setUploadMethod('library')}
                className={`flex-1 py-2 px-3 text-sm font-medium rounded-md transition-colors ${
                  uploadMethod === 'library'
                    ? 'bg-white text-gray-900 shadow-sm'
                    : 'text-gray-500 hover:text-gray-700'
                }`}
              >
                Library
              </button>
            </div>

            {/* Upload Method Content */}
            {uploadMethod === 'upload' && (
              <div className="space-y-4">
                {/* Dropzone */}
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
                    <p className="text-blue-600">Drop images here...</p>
                  ) : (
                    <>
                      <p className="text-gray-600 mb-2">Drag & drop images here, or click to select</p>
                      <p className="text-sm text-gray-500">PNG, JPG, GIF up to 10MB</p>
                    </>
                  )}
                </div>

                {/* Uploaded Images */}
                {images.length > 0 && (
                  <div className="space-y-2">
                    <h4 className="text-sm font-medium text-gray-700">Uploaded Images</h4>
                    <div className="grid grid-cols-2 gap-2">
                      {images.map((image) => (
                        <div
                          key={image.id}
                          className={`relative group cursor-pointer rounded-lg overflow-hidden border-2 transition-colors ${
                            selectedImage?.id === image.id
                              ? 'border-blue-500'
                              : 'border-gray-200 hover:border-gray-300'
                          }`}
                          onClick={() => setSelectedImage(image)}
                        >
                          <img
                            src={image.preview}
                            alt="Preview"
                            className="w-full h-20 object-cover"
                          />
                          <button
                            onClick={(e) => {
                              e.stopPropagation()
                              removeImage(image.id)
                            }}
                            className="absolute top-1 right-1 p-1 bg-red-500 text-white rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                          >
                            <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                              <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                            </svg>
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}

            {uploadMethod === 'url' && (
              <div className="space-y-4">
                <div>
                  <label htmlFor="imageUrl" className="block text-sm font-medium text-gray-700 mb-1">
                    Image URL
                  </label>
                  <input
                    type="url"
                    id="imageUrl"
                    value={imageUrl}
                    onChange={(e) => setImageUrl(e.target.value)}
                    placeholder="https://example.com/image.jpg"
                    className={`block w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-1 sm:text-sm ${
                      imageUrl && !isValidUrl
                        ? 'border-red-300 focus:ring-red-500 focus:border-red-500'
                        : 'border-gray-300 focus:ring-blue-500 focus:border-blue-500'
                    }`}
                  />
                  {imageUrl && !isValidUrl && (
                    <p className="mt-1 text-sm text-red-600">Please enter a valid image URL</p>
                  )}
                </div>
              </div>
            )}

            {uploadMethod === 'library' && (
              <div className="space-y-4">
                <p className="text-sm text-gray-500">Media library integration coming soon...</p>
              </div>
            )}

            {/* Alt Text */}
            <div className="mt-6">
              <label htmlFor="altText" className="block text-sm font-medium text-gray-700 mb-1">
                Alt Text
              </label>
              <input
                type="text"
                id="altText"
                value={altText}
                onChange={(e) => setAltText(e.target.value)}
                placeholder="Describe the image for accessibility"
                className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
              />
              <p className="mt-1 text-xs text-gray-500">
                Alt text helps screen readers and improves SEO
              </p>
            </div>

            {/* Crop Toggle */}
            {selectedImage && (
              <div className="mt-4">
                <label className="flex items-center">
                  <input
                    type="checkbox"
                    checked={showCropper}
                    onChange={(e) => setShowCropper(e.target.checked)}
                    className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  />
                  <span className="ml-2 text-sm text-gray-700">Crop image</span>
                </label>
              </div>
            )}
          </div>

          {/* Main Content */}
          <div className="lg:w-2/3 p-6 overflow-y-auto">
            {/* Preview */}
            {((uploadMethod === 'upload' && selectedImage) || (uploadMethod === 'url' && isValidUrl)) && (
              <div className="mb-6">
                <h4 className="text-sm font-medium text-gray-700 mb-2">Preview</h4>
                <div className="border border-gray-200 rounded-lg overflow-hidden">
                  {uploadMethod === 'upload' && selectedImage && showCropper ? (
                    <ReactCrop
                      crop={crop}
                      onChange={(c) => setCrop(c)}
                      onComplete={(c) => setCompletedCrop(c)}
                      aspect={undefined}
                    >
                      <img
                        ref={imageRef}
                        src={selectedImage.preview}
                        alt="Crop preview"
                        onLoad={handleImageLoad}
                        className="max-w-full h-auto"
                      />
                    </ReactCrop>
                  ) : (
                    <img
                      src={uploadMethod === 'upload' ? selectedImage?.preview : imageUrl}
                      alt="Preview"
                      className="max-w-full h-auto"
                    />
                  )}
                </div>
              </div>
            )}

            {/* Instructions */}
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <div className="flex">
                <svg className="w-5 h-5 text-blue-600 mt-0.5 mr-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <div>
                  <h4 className="text-sm font-medium text-blue-800 mb-1">Image Guidelines</h4>
                  <ul className="text-sm text-blue-700 space-y-1">
                    <li>• Use high-quality images for better engagement</li>
                    <li>• Add descriptive alt text for accessibility</li>
                    <li>• Optimize images for web (under 10MB)</li>
                    <li>• Consider your brand guidelines when selecting images</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="flex justify-end space-x-3 p-6 bg-gray-50 border-t border-gray-200">
          <button
            onClick={onClose}
            className="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleInsertImage}
            disabled={!canInsert || uploading}
            className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {uploading ? (
              <>
                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2" />
                Uploading...
              </>
            ) : (
              <>
                <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                Insert Image
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}

export default ImageUploadModal