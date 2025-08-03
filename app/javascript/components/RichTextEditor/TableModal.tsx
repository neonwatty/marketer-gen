import React, { useState, useEffect, useRef } from 'react'
import { Editor } from '@tiptap/react'

interface TableModalProps {
  editor: Editor
  onClose: () => void
}

export const TableModal: React.FC<TableModalProps> = ({ editor, onClose }) => {
  const [rows, setRows] = useState(3)
  const [cols, setCols] = useState(3)
  const [withHeaderRow, setWithHeaderRow] = useState(true)
  const [previewGrid, setPreviewGrid] = useState<boolean[][]>([])
  const modalRef = useRef<HTMLDivElement>(null)

  // Initialize preview grid
  useEffect(() => {
    const grid = Array(10).fill(null).map(() => Array(10).fill(false))
    setPreviewGrid(grid)
  }, [])

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

  const handleCellHover = (row: number, col: number) => {
    const newGrid = previewGrid.map((r, rowIndex) =>
      r.map((c, colIndex) => rowIndex <= row && colIndex <= col)
    )
    setPreviewGrid(newGrid)
    setRows(row + 1)
    setCols(col + 1)
  }

  const handleCellClick = (row: number, col: number) => {
    const finalRows = row + 1
    const finalCols = col + 1
    insertTable(finalRows, finalCols)
  }

  const insertTable = (rows: number, cols: number) => {
    editor.chain().focus().insertTable({
      rows,
      cols,
      withHeaderRow
    }).run()
    onClose()
  }

  const insertCustomTable = () => {
    if (rows > 0 && cols > 0) {
      insertTable(rows, cols)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div
        ref={modalRef}
        className="bg-white rounded-lg shadow-xl border border-gray-200 p-6 max-w-md w-full mx-4"
      >
        {/* Header */}
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-gray-900">Insert Table</h3>
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

        {/* Visual Table Selector */}
        <div className="mb-6">
          <h4 className="text-sm font-medium text-gray-700 mb-2">Select table size</h4>
          <div className="border border-gray-300 rounded-lg p-3 bg-gray-50">
            <div className="grid grid-cols-10 gap-1 mb-2">
              {previewGrid.map((row, rowIndex) =>
                row.map((isSelected, colIndex) => (
                  <button
                    key={`${rowIndex}-${colIndex}`}
                    type="button"
                    className={`w-4 h-4 border transition-colors ${
                      isSelected
                        ? 'bg-blue-500 border-blue-600'
                        : 'bg-white border-gray-300 hover:bg-gray-100'
                    }`}
                    onMouseEnter={() => handleCellHover(rowIndex, colIndex)}
                    onClick={() => handleCellClick(rowIndex, colIndex)}
                  />
                ))
              )}
            </div>
            <p className="text-sm text-gray-600 text-center">
              {rows} × {cols} table
            </p>
          </div>
        </div>

        {/* Custom Size Input */}
        <div className="mb-6">
          <h4 className="text-sm font-medium text-gray-700 mb-3">Or specify custom size</h4>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label htmlFor="rows" className="block text-sm text-gray-600 mb-1">
                Rows
              </label>
              <input
                type="number"
                id="rows"
                min="1"
                max="20"
                value={rows}
                onChange={(e) => setRows(Math.max(1, parseInt(e.target.value) || 1))}
                className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
              />
            </div>
            <div>
              <label htmlFor="cols" className="block text-sm text-gray-600 mb-1">
                Columns
              </label>
              <input
                type="number"
                id="cols"
                min="1"
                max="10"
                value={cols}
                onChange={(e) => setCols(Math.max(1, parseInt(e.target.value) || 1))}
                className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
              />
            </div>
          </div>
        </div>

        {/* Options */}
        <div className="mb-6">
          <div className="flex items-center">
            <input
              type="checkbox"
              id="headerRow"
              checked={withHeaderRow}
              onChange={(e) => setWithHeaderRow(e.target.checked)}
              className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <label htmlFor="headerRow" className="ml-2 block text-sm text-gray-700">
              Include header row
            </label>
          </div>
          <p className="mt-1 text-xs text-gray-500 ml-6">
            First row will be styled as table headers
          </p>
        </div>

        {/* Preview */}
        <div className="mb-6">
          <h4 className="text-sm font-medium text-gray-700 mb-2">Preview</h4>
          <div className="border border-gray-300 rounded overflow-hidden">
            <table className="w-full text-sm">
              <tbody>
                {Array(Math.min(rows, 4)).fill(null).map((_, rowIndex) => (
                  <tr key={rowIndex} className={withHeaderRow && rowIndex === 0 ? 'bg-gray-100' : ''}>
                    {Array(Math.min(cols, 4)).fill(null).map((_, colIndex) => (
                      <td
                        key={colIndex}
                        className={`border border-gray-300 px-2 py-1 text-center ${
                          withHeaderRow && rowIndex === 0 ? 'font-medium' : ''
                        }`}
                      >
                        {withHeaderRow && rowIndex === 0 
                          ? `Header ${colIndex + 1}`
                          : `Cell ${rowIndex + 1}-${colIndex + 1}`
                        }
                      </td>
                    ))}
                    {cols > 4 && (
                      <td className="border border-gray-300 px-2 py-1 text-center text-gray-500">
                        ...
                      </td>
                    )}
                  </tr>
                ))}
                {rows > 4 && (
                  <tr>
                    {Array(Math.min(cols + (cols > 4 ? 1 : 0), 5)).fill(null).map((_, colIndex) => (
                      <td key={colIndex} className="border border-gray-300 px-2 py-1 text-center text-gray-500">
                        ...
                      </td>
                    ))}
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Buttons */}
        <div className="flex justify-end space-x-3">
          <button
            onClick={onClose}
            className="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={insertCustomTable}
            className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
          >
            <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h18M3 6h18m-9 8h9m-9 4h9M4 15h4m0-2v6" />
            </svg>
            Insert Table
          </button>
        </div>

        {/* Table Tips */}
        <div className="mt-6 pt-4 border-t border-gray-200">
          <h4 className="text-sm font-medium text-gray-700 mb-2">Table Tips</h4>
          <ul className="text-xs text-gray-600 space-y-1">
            <li>• Right-click on a table to access editing options</li>
            <li>• Use Tab to navigate between cells</li>
            <li>• Tables are responsive and mobile-friendly</li>
            <li>• You can add or remove rows and columns later</li>
          </ul>
        </div>
      </div>
    </div>
  )
}

export default TableModal