module Branding
  class AssetProcessor
    attr_reader :brand_asset, :errors

    def initialize(brand_asset)
      @brand_asset = brand_asset
      @errors = []
    end

    def process
      return false unless brand_asset.file.attached?
      
      brand_asset.mark_as_processing!
      
      begin
        case determine_asset_type
        when :pdf
          process_pdf
        when :document
          process_document
        when :image
          process_image
        when :archive
          process_archive
        else
          add_error("Unsupported file type: #{brand_asset.content_type}")
          return false
        end
        
        brand_asset.mark_as_completed!
        true
      rescue StandardError => e
        add_error("Processing failed: #{e.message}")
        brand_asset.mark_as_failed!(e.message)
        false
      end
    end

    private

    def determine_asset_type
      return :pdf if brand_asset.content_type == "application/pdf"
      return :document if brand_asset.document?
      return :image if brand_asset.image?
      return :archive if brand_asset.archive?
      nil
    end

    def process_pdf
      text = extract_pdf_text
      metadata = extract_pdf_metadata
      
      brand_asset.update!(
        extracted_text: text,
        extracted_data: {
          page_count: metadata[:page_count],
          title: metadata[:title],
          author: metadata[:author],
          creation_date: metadata[:creation_date]
        }
      )
      
      analyze_brand_content(text)
    end

    def extract_pdf_text
      text = ""
      
      brand_asset.file.blob.open do |file|
        reader = PDF::Reader.new(file)
        reader.pages.each do |page|
          text += page.text + "\n"
        end
      end
      
      text.strip
    end

    def extract_pdf_metadata
      metadata = {}
      
      brand_asset.file.blob.open do |file|
        reader = PDF::Reader.new(file)
        metadata[:page_count] = reader.page_count
        metadata[:title] = reader.info[:Title]
        metadata[:author] = reader.info[:Author]
        metadata[:creation_date] = reader.info[:CreationDate]
      end
      
      metadata
    end

    def process_document
      text = extract_document_text
      
      brand_asset.update!(
        extracted_text: text,
        extracted_data: {
          word_count: text.split.size,
          character_count: text.length
        }
      )
      
      analyze_brand_content(text)
    end

    def extract_document_text
      case brand_asset.content_type
      when "text/plain"
        extract_plain_text
      when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        extract_docx_text
      else
        ""
      end
    end

    def extract_plain_text
      brand_asset.file.download
    end

    def extract_docx_text
      text = ""
      
      brand_asset.file.blob.open do |file|
        doc = Docx::Document.open(file)
        doc.paragraphs.each do |p|
          text += p.to_s + "\n"
        end
      end
      
      text.strip
    end

    def process_image
      metadata = extract_image_metadata
      
      brand_asset.update!(
        extracted_data: {
          width: metadata[:width],
          height: metadata[:height],
          format: metadata[:format],
          color_profile: metadata[:color_profile],
          dominant_colors: extract_dominant_colors
        }
      )
      
      # For logos and visual assets, we might want to run through image recognition
      # or extract color palettes for brand consistency
    end

    def extract_image_metadata
      metadata = {}
      
      brand_asset.file.blob.analyze unless brand_asset.file.blob.analyzed?
      
      metadata[:width] = brand_asset.file.blob.metadata[:width]
      metadata[:height] = brand_asset.file.blob.metadata[:height]
      metadata[:format] = brand_asset.file.blob.content_type
      
      metadata
    end

    def extract_dominant_colors
      # This is a placeholder - in production, you'd use a service like
      # ImageMagick or a color extraction library
      []
    end

    def process_archive
      # Extract and process files within the archive
      extracted_files = []
      
      brand_asset.file.blob.open do |file|
        Zip::File.open(file) do |zip_file|
          zip_file.each do |entry|
            next if entry.directory?
            
            extracted_files << {
              name: entry.name,
              size: entry.size,
              type: determine_file_type(entry.name)
            }
          end
        end
      end
      
      brand_asset.update!(
        extracted_data: {
          file_count: extracted_files.size,
          files: extracted_files
        }
      )
    end

    def determine_file_type(filename)
      extension = File.extname(filename).downcase
      
      case extension
      when '.pdf' then 'pdf'
      when '.doc', '.docx' then 'document'
      when '.txt' then 'text'
      when '.jpg', '.jpeg', '.png', '.gif' then 'image'
      else 'other'
      end
    end

    def analyze_brand_content(text)
      return if text.blank?
      
      # Queue job for AI analysis
      BrandAnalysisJob.perform_later(brand_asset.brand, text)
    end

    def add_error(message)
      @errors << message
    end
  end
end