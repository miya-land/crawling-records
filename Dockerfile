FROM public.ecr.aws/lambda/ruby:3.2

# 依存関係をインストール
# gccとかmakeが必要なのは、C言語で書かれたGemをコンパイルするために必要
RUN yum update -y && yum install -y \
  gcc \
  make \
	libyaml-devel \
	zlib-devel \
	libffi-devel \
	patch \
	readline-devel && \
	yum clean all && \
	rm -rf /var/cache/yum

# 作業ディレクトリを指定
# AWS Lambda がデフォルトで /var/task ディレクトリからコードを実行するため、このディレクトリにコードを配置します。
WORKDIR ${LAMBDA_TASK_ROOT} 

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ${LAMBDA_TASK_ROOT}/

# Install Bundler and the specified gems
RUN gem install bundler && \
    bundle config set --local path 'vendor/bundle' && \
    bundle install

# Copy function code
COPY lambda_function.rb ${LAMBDA_TASK_ROOT}/    

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "lambda_function.LambdaFunction::Handler.process" ]
