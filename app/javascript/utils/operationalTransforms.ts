// Operational Transform implementation for collaborative content editing

export interface Operation {
  type: 'retain' | 'insert' | 'delete';
  length?: number;
  text?: string;
  attributes?: Record<string, unknown>;
}

export interface TransformResult {
  operationA: Operation[];
  operationB: Operation[];
}

export class OperationalTransformEngine {
  /**
   * Apply an operation to a text string
   */
  static apply(text: string, operations: Operation[]): string {
    let result = text;
    let offset = 0;

    for (const op of operations) {
      switch (op.type) {
        case 'retain':
          offset += op.length || 0;
          break;
        
        case 'insert': {
          const insertText = op.text || '';
          result = result.slice(0, offset) + insertText + result.slice(offset);
          offset += insertText.length;
          break;
        }
        
        case 'delete': {
          const deleteLength = op.length || 0;
          result = result.slice(0, offset) + result.slice(offset + deleteLength);
          break;
        }
      }
    }

    return result;
  }

  /**
   * Transform two concurrent operations against each other
   */
  static transform(operationA: Operation[], operationB: Operation[]): TransformResult {
    const result: TransformResult = {
      operationA: [],
      operationB: []
    };

    let indexA = 0;
    let indexB = 0;
    const _offsetA = 0;
    let _offsetB = 0;

    while (indexA < operationA.length || indexB < operationB.length) {
      const opA = operationA[indexA];
      const opB = operationB[indexB];

      // If one operation is finished, copy remaining from the other
      if (!opA) {
        result.operationA.push(...operationB.slice(indexB));
        break;
      }
      if (!opB) {
        result.operationB.push(...operationA.slice(indexA));
        break;
      }

      if (opA.type === 'retain' && opB.type === 'retain') {
        // Both retain - take minimum length
        const minLength = Math.min(opA.length || 0, opB.length || 0);
        
        result.operationA.push({ type: 'retain', length: minLength });
        result.operationB.push({ type: 'retain', length: minLength });

        this.advanceOperation(operationA, indexA, minLength);
        this.advanceOperation(operationB, indexB, minLength);
        
        if ((opA.length || 0) === minLength) {indexA++;}
        if ((opB.length || 0) === minLength) {indexB++;}

      } else if (opA.type === 'insert' && opB.type === 'insert') {
        // Both insert - A wins (arbitrary choice for tie-breaking)
        result.operationA.push({ ...opA });
        result.operationB.push({ 
          type: 'retain', 
          length: opA.text?.length || 0 
        });
        
        indexA++;
        _offsetB = _offsetB + (opA.text?.length || 0);

      } else if (opA.type === 'insert') {
        // A inserts, B retains over the insertion
        result.operationA.push({ ...opA });
        result.operationB.push({ 
          type: 'retain', 
          length: opA.text?.length || 0 
        });
        
        indexA++;

      } else if (opB.type === 'insert') {
        // B inserts, A retains over the insertion
        result.operationA.push({ 
          type: 'retain', 
          length: opB.text?.length || 0 
        });
        result.operationB.push({ ...opB });
        
        indexB++;

      } else if (opA.type === 'delete' && opB.type === 'delete') {
        // Both delete same content - only one delete needed
        const minLength = Math.min(opA.length || 0, opB.length || 0);
        
        this.advanceOperation(operationA, indexA, minLength);
        this.advanceOperation(operationB, indexB, minLength);
        
        if ((opA.length || 0) === minLength) {indexA++;}
        if ((opB.length || 0) === minLength) {indexB++;}

      } else if (opA.type === 'delete' && opB.type === 'retain') {
        // A deletes, B needs to skip over the deletion
        const deleteLength = opA.length || 0;
        const retainLength = opB.length || 0;
        
        if (deleteLength <= retainLength) {
          result.operationA.push({ ...opA });
          this.advanceOperation(operationB, indexB, deleteLength);
          
          if (retainLength === deleteLength) {indexB++;}
          indexA++;
        } else {
          result.operationA.push({ type: 'delete', length: retainLength });
          this.advanceOperation(operationA, indexA, retainLength);
          indexB++;
        }

      } else if (opA.type === 'retain' && opB.type === 'delete') {
        // B deletes, A needs to skip over the deletion
        const retainLength = opA.length || 0;
        const deleteLength = opB.length || 0;
        
        if (deleteLength <= retainLength) {
          result.operationB.push({ ...opB });
          this.advanceOperation(operationA, indexA, deleteLength);
          
          if (retainLength === deleteLength) {indexA++;}
          indexB++;
        } else {
          result.operationB.push({ type: 'delete', length: retainLength });
          this.advanceOperation(operationB, indexB, retainLength);
          indexA++;
        }
      }
    }

    return result;
  }

  /**
   * Reduce the length of an operation by the specified amount
   */
  private static advanceOperation(operations: Operation[], index: number, length: number): void {
    const op = operations[index];
    if (op && (op.type === 'retain' || op.type === 'delete')) {
      op.length = (op.length || 0) - length;
    }
  }

  /**
   * Compose two operations into a single operation
   */
  static compose(operationA: Operation[], operationB: Operation[]): Operation[] {
    const result: Operation[] = [];
    let indexA = 0;
    let indexB = 0;

    while (indexA < operationA.length || indexB < operationB.length) {
      const opA = operationA[indexA];
      const opB = operationB[indexB];

      if (!opB) {
        result.push(...operationA.slice(indexA));
        break;
      }

      if (!opA) {
        result.push(...operationB.slice(indexB));
        break;
      }

      if (opA.type === 'retain' && opB.type === 'retain') {
        const minLength = Math.min(opA.length || 0, opB.length || 0);
        result.push({ type: 'retain', length: minLength });
        
        this.advanceOperation(operationA, indexA, minLength);
        this.advanceOperation(operationB, indexB, minLength);
        
        if ((opA.length || 0) === 0) {indexA++;}
        if ((opB.length || 0) === 0) {indexB++;}

      } else if (opA.type === 'insert') {
        result.push({ ...opA });
        indexA++;

      } else if (opB.type === 'insert') {
        result.push({ ...opB });
        indexB++;

      } else if (opA.type === 'retain' && opB.type === 'delete') {
        const minLength = Math.min(opA.length || 0, opB.length || 0);
        result.push({ type: 'delete', length: minLength });
        
        this.advanceOperation(operationA, indexA, minLength);
        this.advanceOperation(operationB, indexB, minLength);
        
        if ((opA.length || 0) === 0) {indexA++;}
        if ((opB.length || 0) === 0) {indexB++;}

      } else if (opA.type === 'delete') {
        indexA++; // Skip deletes in first operation

      } else if (opB.type === 'retain') {
        indexB++; // Skip retains in second operation
      }
    }

    return this.normalizeOperations(result);
  }

  /**
   * Normalize operations by merging consecutive operations of the same type
   */
  static normalizeOperations(operations: Operation[]): Operation[] {
    const result: Operation[] = [];
    
    for (const op of operations) {
      const lastOp = result[result.length - 1];
      
      if (lastOp && lastOp.type === op.type) {
        if (op.type === 'retain' || op.type === 'delete') {
          lastOp.length = (lastOp.length || 0) + (op.length || 0);
        } else if (op.type === 'insert') {
          lastOp.text = (lastOp.text || '') + (op.text || '');
        }
      } else {
        result.push({ ...op });
      }
    }
    
    return result.filter(op => {
      // Remove empty operations
      if (op.type === 'retain' || op.type === 'delete') {
        return (op.length || 0) > 0;
      }
      if (op.type === 'insert') {
        return (op.text || '').length > 0;
      }
      return true;
    });
  }

  /**
   * Convert a simple change into operations
   */
  static fromChange(oldText: string, newText: string, changeStart: number, changeEnd: number): Operation[] {
    const operations: Operation[] = [];
    
    // Retain text before change
    if (changeStart > 0) {
      operations.push({ type: 'retain', length: changeStart });
    }
    
    // Delete old text
    const deleteLength = changeEnd - changeStart;
    if (deleteLength > 0) {
      operations.push({ type: 'delete', length: deleteLength });
    }
    
    // Insert new text
    const insertText = newText.slice(changeStart, changeStart + (newText.length - oldText.length + deleteLength));
    if (insertText.length > 0) {
      operations.push({ type: 'insert', text: insertText });
    }
    
    // Retain text after change
    const remainingLength = oldText.length - changeEnd;
    if (remainingLength > 0) {
      operations.push({ type: 'retain', length: remainingLength });
    }
    
    return this.normalizeOperations(operations);
  }

  /**
   * Check if operations are valid
   */
  static isValid(operations: Operation[], baseTextLength: number): boolean {
    let length = 0;
    
    for (const op of operations) {
      switch (op.type) {
        case 'retain':
          length += op.length || 0;
          break;
        case 'delete':
          length += op.length || 0;
          break;
        case 'insert':
          // Inserts don't consume base text length
          break;
      }
    }
    
    return length === baseTextLength;
  }

  /**
   * Calculate the result length after applying operations
   */
  static resultLength(operations: Operation[], _baseTextLength: number): number {
    let length = 0;
    
    for (const op of operations) {
      switch (op.type) {
        case 'retain':
          length += op.length || 0;
          break;
        case 'insert':
          length += op.text?.length || 0;
          break;
        case 'delete':
          // Deletes don't contribute to result length
          break;
      }
    }
    
    return length;
  }
}

/**
 * Text change detector for editor integration
 */
export class TextChangeDetector {
  private lastText: string = '';
  private lastSelection: { start: number; end: number } = { start: 0, end: 0 };

  updateText(newText: string, selection: { start: number; end: number }): Operation[] | null {
    if (newText === this.lastText) {
      // Only selection changed
      this.lastSelection = selection;
      return null;
    }

    const operations = this.detectChange(this.lastText, newText, this.lastSelection, selection);
    
    this.lastText = newText;
    this.lastSelection = selection;
    
    return operations;
  }

  private detectChange(
    oldText: string,
    newText: string,
    _oldSelection: { start: number; end: number },
    _newSelection: { start: number; end: number }
  ): Operation[] {
    // Find the start and end of the change
    let changeStart = 0;
    let changeEnd = oldText.length;
    
    // Find common prefix
    while (changeStart < oldText.length && 
           changeStart < newText.length && 
           oldText[changeStart] === newText[changeStart]) {
      changeStart++;
    }
    
    // Find common suffix
    let oldIndex = oldText.length - 1;
    let newIndex = newText.length - 1;
    
    while (oldIndex >= changeStart && 
           newIndex >= changeStart && 
           oldText[oldIndex] === newText[newIndex]) {
      oldIndex--;
      newIndex--;
    }
    
    changeEnd = oldIndex + 1;
    
    return OperationalTransformEngine.fromChange(oldText, newText, changeStart, changeEnd);
  }

  reset(text: string = '', selection: { start: number; end: number } = { start: 0, end: 0 }): void {
    this.lastText = text;
    this.lastSelection = selection;
  }
}