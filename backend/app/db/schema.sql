-- ============================================
-- AI RESEARCH ASSISTANT DATABASE SCHEMA
-- ============================================
-- Optimized for multimodal paper understanding
-- with hierarchical document structure,
-- knowledge graphs, and conversational memory
-- ============================================

-- ============================================
-- CORE TABLES
-- ============================================

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    
    -- User expertise level for adaptive explanations
    expertise_level VARCHAR(50) DEFAULT 'beginner',
    -- Values: beginner, undergraduate, graduate, researcher, expert
    
    preferences JSONB DEFAULT '{}',
    -- {explanation_depth: int, show_equations: bool, language: str, ...}
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    
    INDEX idx_users_email (email),
    INDEX idx_users_username (username)
);

-- Papers table - core document metadata
CREATE TABLE papers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Basic metadata
    title VARCHAR(500) NOT NULL,
    abstract TEXT,
    authors TEXT[] NOT NULL DEFAULT '{}',
    year INTEGER,
    doi VARCHAR(255) UNIQUE,
    arxiv_id VARCHAR(100) UNIQUE,
    publication_venue VARCHAR(255),
    url VARCHAR(500),
    
    -- File information
    file_path VARCHAR(500) NOT NULL,
    file_size BIGINT,
    file_hash VARCHAR(255) UNIQUE NOT NULL,
    
    -- Processing status
    status VARCHAR(50) DEFAULT 'pending',
    -- Values: pending, processing, completed, failed, archived
    processing_error TEXT,
    ingestion_started_at TIMESTAMP,
    ingestion_completed_at TIMESTAMP,
    
    -- Content statistics
    page_count INTEGER,
    word_count INTEGER,
    language VARCHAR(10) DEFAULT 'en',
    
    -- Structural counts
    citations_count INTEGER DEFAULT 0,
    figures_count INTEGER DEFAULT 0,
    tables_count INTEGER DEFAULT 0,
    equations_count INTEGER DEFAULT 0,
    
    -- Hierarchical sections stored as JSONB array
    sections JSONB DEFAULT '[]',
    -- [{id, title, level, section_type, page_start, page_end}, ...]
    
    -- Knowledge graph data
    key_concepts TEXT[] DEFAULT '{}',
    methodologies TEXT[] DEFAULT '{}',
    datasets_mentioned TEXT[] DEFAULT '{}',
    
    -- Relationships to other papers
    related_paper_ids UUID[] DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    
    CONSTRAINT unique_user_file UNIQUE(user_id, file_hash),
    INDEX idx_papers_user_id (user_id),
    INDEX idx_papers_status (status),
    INDEX idx_papers_created_at (created_at DESC),
    INDEX idx_papers_doi (doi),
    INDEX idx_papers_arxiv_id (arxiv_id)
);


-- ============================================
-- DOCUMENT STRUCTURE TABLES
-- ============================================

-- Sections table - hierarchical paper structure
CREATE TABLE sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_id UUID NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    
    -- Hierarchical relationship
    parent_section_id UUID REFERENCES sections(id) ON DELETE SET NULL,
    
    title VARCHAR(500) NOT NULL,
    section_type VARCHAR(50),
    -- Values: abstract, introduction, related_work, methodology, 
    --         results, discussion, conclusion, references, appendix
    
    level INTEGER DEFAULT 0,
    -- 0 = top level, 1 = subsection, etc.
    
    sequence_number VARCHAR(50),
    -- "1", "1.1", "1.1.1", "2.3.2", etc.
    
    -- Position in document
    start_page INTEGER,
    end_page INTEGER,
    start_position INTEGER NOT NULL,
    end_position INTEGER NOT NULL,
    
    -- Content
    content TEXT NOT NULL,
    
    -- Metadata
    figures_in_section UUID[] DEFAULT '{}',
    tables_in_section UUID[] DEFAULT '{}',
    equations_in_section UUID[] DEFAULT '{}',
    citations_in_section UUID[] DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_sections_paper_id (paper_id),
    INDEX idx_sections_parent (parent_section_id),
    INDEX idx_sections_type (section_type)
);

-- Chunks table - semantic units for RAG
CREATE TABLE chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_id UUID NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    section_id UUID REFERENCES sections(id) ON DELETE SET NULL,
    
    -- Content
    content TEXT NOT NULL,
    chunk_type VARCHAR(50),
    -- Values: text, equation, figure_caption, table_caption, 
    --         code, methodology, result, discussion
    
    -- Position tracking
    page_number INTEGER,
    start_position INTEGER,
    end_position INTEGER,
    
    -- Semantic metadata
    metadata JSONB DEFAULT '{}',
    -- {importance: float, keywords: [str], entities: [str]}
    
    -- Vector embedding reference (Qdrant)
    vector_id VARCHAR(255) UNIQUE,
    embedding_model VARCHAR(100),
    
    -- Cross-references to multimodal content
    figure_ids UUID[] DEFAULT '{}',
    equation_ids UUID[] DEFAULT '{}',
    citation_ids UUID[] DEFAULT '{}',
    table_ids UUID[] DEFAULT '{}',
    
    -- For efficient retrieval
    chunk_hash VARCHAR(255) UNIQUE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_chunks_paper_id (paper_id),
    INDEX idx_chunks_section_id (section_id),
    INDEX idx_chunks_type (chunk_type),
    INDEX idx_chunks_vector_id (vector_id)
);


-- ============================================
-- MULTIMODAL CONTENT TABLES
-- ============================================

-- Figures table
CREATE TABLE figures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_id UUID NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    
    figure_number VARCHAR(50),
    title VARCHAR(500),
    caption TEXT NOT NULL,
    description TEXT,
    -- AI-generated detailed description of figure
    
    -- File storage
    image_path VARCHAR(500) NOT NULL,
    image_size BIGINT,
    image_format VARCHAR(20),
    
    -- Position in document
    page_number INTEGER,
    position_index INTEGER,
    
    -- Content analysis
    has_text BOOLEAN DEFAULT FALSE,
    extracted_text TEXT,
    -- OCR extracted text from figure
    
    detected_objects TEXT[],
    -- ['plot', 'bar_chart', 'line_chart', 'heatmap', 'diagram', ...]
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_figures_paper_id (paper_id),
    INDEX idx_figures_page (page_number)
);

-- Equations table
CREATE TABLE equations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_id UUID NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    
    equation_number VARCHAR(50),
    latex_code TEXT NOT NULL,
    rendered_image_path VARCHAR(500),
    
    -- Position and context
    section_id UUID REFERENCES sections(id),
    page_number INTEGER,
    surrounding_text TEXT,
    -- Text immediately before/after equation
    
    -- Semantic understanding
    explanation TEXT,
    -- AI-generated explanation
    
    variables_explained JSONB,
    -- {var_name: {symbol: str, meaning: str, units: str}}
    
    intuitive_explanation TEXT,
    -- Layman's explanation of what equation means
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_equations_paper_id (paper_id)
);

-- Tables table
CREATE TABLE paper_tables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_id UUID NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    
    table_number VARCHAR(50),
    title VARCHAR(500),
    caption TEXT,
    
    -- Multiple representations for different use cases
    html_content TEXT,
    csv_content TEXT,
    markdown_content TEXT,
    structured_data JSONB,
    -- Parsed table as nested JSON
    
    -- Interpretation
    interpretation TEXT,
    -- AI-generated interpretation of what table shows
    
    key_insights TEXT[],
    -- Important findings from the table
    
    -- Position
    page_number INTEGER,
    position_index INTEGER,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_tables_paper_id (paper_id)
);


-- ============================================
-- CITATION & REFERENCE TABLES
-- ============================================

-- Citations table - references cited in paper
CREATE TABLE citations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_id UUID NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    
    -- Citation metadata
    cited_authors TEXT[] NOT NULL DEFAULT '{}',
    cited_title VARCHAR(500),
    cited_year INTEGER,
    cited_venue VARCHAR(255),
    citation_key VARCHAR(255),
    -- BibTeX key or similar
    
    doi VARCHAR(255),
    arxiv_id VARCHAR(100),
    url VARCHAR(500),
    
    -- Context of citation
    context_chunks UUID[] DEFAULT '{}',
    -- Which chunks cite this reference
    
    citation_count INTEGER DEFAULT 1,
    -- How many times cited
    
    -- Link to papers table if we have the cited paper
    related_cited_paper_id UUID REFERENCES papers(id) ON DELETE SET NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_citations_paper_id (paper_id),
    INDEX idx_citations_year (cited_year),
    INDEX idx_citations_doi (doi)
);

-- Citation relationships for knowledge graph
CREATE TABLE citation_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_paper_id UUID NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    target_citation_id UUID NOT NULL REFERENCES citations(id) ON DELETE CASCADE,
    
    relationship_type VARCHAR(50),
    -- Values: cited_by, cites, same_domain, related_methodology, 
    --         builds_on, contradicts
    
    strength FLOAT DEFAULT 1.0,
    -- Confidence/importance of relationship 0-1
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_citation_rel UNIQUE(source_paper_id, target_citation_id, relationship_type),
    INDEX idx_citation_rels_source (source_paper_id)
);


-- ============================================
-- CONVERSATION & MEMORY TABLES
-- ============================================

-- Conversations table - chat sessions
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    paper_id UUID REFERENCES papers(id) ON DELETE SET NULL,
    
    -- Session metadata
    title VARCHAR(500),
    mode VARCHAR(50) DEFAULT 'research_tutor',
    -- Values: research_tutor, paper_explainer, critic, implementer, presenter
    
    -- Conversation context
    context JSONB DEFAULT '{}',
    -- {focus_sections: [uuid], focus_concepts: [str], expertise_adapted: bool}
    
    is_archived BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    
    INDEX idx_conversations_user_id (user_id),
    INDEX idx_conversations_paper_id (paper_id),
    INDEX idx_conversations_created_at (created_at DESC)
);

-- Messages table - individual messages in conversation
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    
    role VARCHAR(50) NOT NULL,
    -- Values: user, assistant
    
    content TEXT NOT NULL,
    
    -- Retrieval context
    retrieved_chunks UUID[] DEFAULT '{}',
    retrieved_citations UUID[] DEFAULT '{}',
    retrieved_figures UUID[] DEFAULT '{}',
    
    -- Message metadata
    token_count INTEGER,
    model_used VARCHAR(100),
    
    -- For follow-up grounding
    follows_up_on_message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_messages_conversation_id (conversation_id),
    INDEX idx_messages_created_at (created_at DESC)
);


-- ============================================
-- KNOWLEDGE GRAPH TABLES
-- ============================================

-- Concepts table - entities extracted from paper
CREATE TABLE concepts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_id UUID NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    
    concept_name VARCHAR(255) NOT NULL,
    concept_type VARCHAR(100),
    -- Values: algorithm, model, metric, dataset, method, 
    --         architecture, loss_function, etc.
    
    description TEXT,
    
    -- When first mentioned
    first_mentioned_page INTEGER,
    occurrences_count INTEGER DEFAULT 1,
    
    -- Semantic information
    synonyms TEXT[] DEFAULT '{}',
    related_concepts UUID[] DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_concept UNIQUE(paper_id, concept_name),
    INDEX idx_concepts_paper_id (paper_id),
    INDEX idx_concepts_type (concept_type)
);

-- Concept relationships - knowledge graph edges
CREATE TABLE concept_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_concept_id UUID NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    target_concept_id UUID NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    
    relationship_type VARCHAR(100),
    -- Values: uses, improves, extends, related_to, variant_of, 
    --         addresses, compares_to, supersedes
    
    strength FLOAT DEFAULT 1.0,
    -- 0-1 confidence/importance
    
    CONSTRAINT unique_concept_rel UNIQUE(source_concept_id, target_concept_id, relationship_type),
    INDEX idx_concept_rels_source (source_concept_id)
);


-- ============================================
-- METHODOLOGY EXTRACTION TABLE
-- ============================================

CREATE TABLE methodologies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_id UUID NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    
    name VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    
    -- Components
    inputs TEXT[] DEFAULT '{}',
    outputs TEXT[] DEFAULT '{}',
    steps TEXT[] DEFAULT '{}',
    
    -- Where in paper
    section_ids UUID[] DEFAULT '{}',
    
    -- Related concepts
    concept_ids UUID[] DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_methodologies_paper_id (paper_id)
);


-- ============================================
-- CACHE & OPTIMIZATION TABLES
-- ============================================

-- Embedding cache to avoid re-computing
CREATE TABLE embedding_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chunk_id UUID NOT NULL REFERENCES chunks(id) ON DELETE CASCADE,
    
    embedding_model VARCHAR(100) NOT NULL,
    vector_id VARCHAR(255),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_embedding UNIQUE(chunk_id, embedding_model),
    INDEX idx_embedding_chunk (chunk_id)
);

-- User activity logs for monitoring
CREATE TABLE user_activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    action VARCHAR(100),
    resource_type VARCHAR(50),
    resource_id UUID,
    
    details JSONB DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_activity_user_id (user_id),
    INDEX idx_activity_action (action),
    INDEX idx_activity_created_at (created_at DESC)
);


-- ============================================
-- INDEXES FOR FULL-TEXT SEARCH
-- ============================================

-- Full-text search indexes
CREATE INDEX idx_papers_title_search ON papers USING GIN(to_tsvector('english', title));
CREATE INDEX idx_papers_abstract_search ON papers USING GIN(to_tsvector('english', abstract));
CREATE INDEX idx_sections_content_search ON sections USING GIN(to_tsvector('english', content));
CREATE INDEX idx_chunks_content_search ON chunks USING GIN(to_tsvector('english', content));
CREATE INDEX idx_citations_title_search ON citations USING GIN(to_tsvector('english', cited_title));


-- ============================================
-- MATERIALIZED VIEWS FOR ANALYTICS
-- ============================================

-- User paper statistics
CREATE VIEW user_paper_stats AS
SELECT 
    u.id as user_id,
    u.username,
    COUNT(p.id) as papers_count,
    COUNT(DISTINCT c.id) as conversations_count,
    SUM(CASE WHEN p.status = 'completed' THEN 1 ELSE 0 END) as processed_papers,
    MAX(p.created_at) as last_paper_uploaded
FROM users u
LEFT JOIN papers p ON u.id = p.user_id AND p.deleted_at IS NULL
LEFT JOIN conversations c ON u.id = c.user_id AND c.deleted_at IS NULL
GROUP BY u.id, u.username;

-- Paper complexity metrics
CREATE VIEW paper_complexity_metrics AS
SELECT 
    p.id,
    p.title,
    p.page_count,
    p.word_count,
    p.citations_count,
    p.figures_count,
    p.tables_count,
    p.equations_count,
    (p.citations_count + p.figures_count + p.tables_count + p.equations_count) as complexity_score
FROM papers p
WHERE p.deleted_at IS NULL;
