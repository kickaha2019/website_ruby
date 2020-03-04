class ContentStart
  def process( article, parents, html)
    if article.has_picture_page?
      html.set_max_floats( article.images.size)
      html.breadcrumbs( parents, article.title, true)
    else
      html.breadcrumbs( parents, article.title, false) if parents.size > 0
    end
    html.start_div( 'payload content')

    article.index( parents, html, article.images.size > 1)

    if article.content.size > 1
      html.start_div( 'story t1')
    end

    if (article.images.size > 0) && (! article.has_picture_page?)
      article.prepare_source_images( html, (article.images.size > 1) || (article.content.size == 1))
    end
  end

  def wrap?
    true
  end
end