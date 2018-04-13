#####################################################################################

# tfstate管理用のs3 bucket, AWSのCredential（初期化終わったら空にしていい）
# skelthon落とす => make env して出来た Makefile.env を Fill => make init
include Makefile.env

# 上記で設定されるパラメータ
TFSTATE_BUCKET        ?= 
AWS_ACCESS_KEY_ID     ?= 
AWS_SECRET_ACCESS_KEY ?= 

#####################################################################################

# このリソースのディレクトリ名
CURRENT_DIR = ${shell basename `pwd`}

TERRAFORM ?= terraform

#####################################################################################

default:
	@echo "do nothing"

Makefile.env: env

env:
	@echo "TFSTATE_BUCKET        ?= ${TFSTATE_BUCKET}" > Makefile.env
	@echo "AWS_ACCESS_KEY_ID     ?= ${AWS_ACCESS_KEY_ID}" >> Makefile.env
	@echo "AWS_SECRET_ACCESS_KEY ?= ${AWS_SECRET_ACCESS_KEY}" >> Makefile.env

# 環境変数にexportしてない場合は、生成後に手動で書き換えること
terraform.tfvars:
	echo "aws_access_key = \"${AWS_ACCESS_KEY_ID}\"" > terraform.tfvars
	echo "aws_secret_key = \"${AWS_SECRET_ACCESS_KEY}\"" >> terraform.tfvars
	echo "tfstate_bucket = \"${TFSTATE_BUCKET}\"" >> terraform.tfvars
	echo "tfstate_object = \"${CURRENT_DIR}\"" >> terraform.tfvars

# 追加モジュールのロードとか。Provider定義後に実行する
# initのbackend setupの段階ではtfvarsを読まないので、トリッキーだが、backend-configで渡す必要あり。
# issue 湧いてるので、そのうち改善されるかも？
# https://github.com/hashicorp/terraform/issues/13022
# init時の対話モードを切り方が分からんので、initだけは、メインシェルで実行してくれ...
init: terraform.tfvars
	${TERRAFORM} init \
		-backend-config "bucket=${TFSTATE_BUCKET}" \
		-backend-config "key=${CURRENT_DIR}" \
		-backend-config "region=ap-northeast-1" \

# シンタックスチェック
test:
	${TERRAFORM} validate 

# 実行内容事前チェック
plan:
	${TERRAFORM} plan -out=tfplan -input=false 

# 実行
apply:
	${TERRAFORM} apply -input=false tfplan 

# test => plan => apply
all: test plan apply

# リソース破棄
destroy:
	${TERRAFORM} plan --destroy -out=tfplan -input=false 

# test => destroy => apply 
clean: test destroy apply

status:
	${TERRAFORM} show

setupTfstate:
	${TERRAFORM} remote config \
		-backend=S3 \
		-backend-config="${TFSTATE_BUCKET}" \
		-backend-config="region=ap-northeast-1" \
		-backend-config="key=${CURRENT_DIR}.tfstate" \
		-backend-config="access_key=${AWS_ACCESS_KEY_ID}" \
		-backend-config="secret_key=${AWS_SECRET_ACCESS_KEY}"

#####################################################################################
