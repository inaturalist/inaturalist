# frozen_string_literal: true

class BlogCategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :site_admin_required
  before_action { render_404 unless @site.blog_v2? }
  before_action :load_blog_category, only: [:edit, :update, :destroy]
  before_action { @responsive = true }

  layout "bootstrap"

  def index
    @blog_categories = @site.blog_categories.
      left_joins( :posts ).
      group( :id ).
      select( "blog_categories.*, COUNT(posts.id) AS posts_count" ).
      order( :position, :label )
  end

  def new
    @blog_category = @site.blog_categories.build
  end

  def edit; end

  def create
    @blog_category = @site.blog_categories.build( blog_category_params )
    if @blog_category.save
      redirect_to blog_categories_path, notice: t( :blog_category_was_successfully_created )
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @blog_category.update( blog_category_params )
      redirect_to blog_categories_path, notice: t( :blog_category_was_successfully_updated )
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @blog_category.destroy
      flash[:notice] = t( :blog_category_was_successfully_deleted )
    else
      flash[:error] = t( :blog_category_in_use, count: @blog_category.posts.count )
    end
    redirect_to blog_categories_path
  end

  private

  def load_blog_category
    render_404 unless ( @blog_category = @site.blog_categories.find_by_id( params[:id] ) )
  end

  def blog_category_params
    params.require( :blog_category ).permit( :label, :position )
  end
end
