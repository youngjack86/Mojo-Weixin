sub Mojo::Weixin::_login {
    my $self = shift;
    $self->info("客户端准备登录...");
    my $api = 'https://login.weixin.qq.com/cgi-bin/mmwebwx-bin/login';
    if(not $self->_is_need_login()){
        $self->info("检测到近期登录活动，尝试直接恢复登录");
        $self->wxuin($self->search_cookie("wxuin"));
        $self->wxsid($self->search_cookie("wxsid"));
        return 1;
    }
    my $qrcode_uuid = $self->_get_qrcode_uuid(); 
    if(not defined $qrcode_uuid){
        $self->info("无法获取到登录二维码，登录失败");
        $self->stop();
    }
    if(not $self->_get_qrcode_image($qrcode_uuid)){
        $self->info("下载二维码失败，客户端退出");
        $self->stop();
    }
    my $i=1;
    $self->info("等待手机微信扫描二维码...");
    while(1){
        my @query_string = (
            uuid    =>  $qrcode_uuid,
            tip     =>  $show_tip ,
            _       =>  $self->now(),
        );
        my $r = $self->http_get($self->gen_url($api,@query_string));
        next unless defined $r;
        my %data = $r=~/window\.(.+?)=(.+?);/g;
        $data{redirect_uri}=~s/^["']|["']$//g if defined $data{redirect_uri};
        if($data{code} == 408){
            select undef,undef,undef,0.5;
            if($i==5){
                $self->info("登录二维码已失效，重新获取二维码");
                $qrcode_uuid = $self->_get_qrcode_uuid();
                $self->_get_qrcode_image($qrcode_uuid);
                $i = 1;
                next;
            }
            $i++;
        }
        elsif($data{code} == 201){
            $self->info("手机微信扫码成功，请在手机微信上点击 [登录] 按钮...");
            $show_tip = 0;
            next;

        }
        elsif($data{code} == 200){
            $self->info("正在进行登录...");
            my $data = $self->http_get($data{redirect_uri} . "&fun=new");
            #<error><ret>0</ret><message>OK</message><skey>@crypt_859d8a8a_3f3db5290570080d1db29da9507e35de</skey><wxsid>rsuMHe7xmA0aHW1D</wxsid><wxuin>138122335</wxuin><pass_ticket>hWdpMVCMqXIVfhXLcsJxYrC6bv785tVDLZAres096ZE%3D</pass_ticket></error
            my %d = $data=~/<([^<>]+?)>([^<>]+?)<\/\1>/g;
            return 0 if $d{ret} != 0;
            $self->skey($d{skey});
            $self->wxsid($d{wxsid});
            $self->wxuin($d{wxuin});
            $self->pass_ticket($d{pass_ticket});
            $self->info("微信登录成功");
            return 1;
        }
        elsif($data{code} == 400){
            $self->info("登录错误，客户端退出");
            $self->stop();
        }
        elsif($data{code} == 500){
            $self->info("登录错误，客户端尝试重新登录...");
            $i = 1;
            $show_tip = 1;
            $qrcode_uuid = $self->_get_qrcode_uuid();
            $self->_get_qrcode_image($qrcode_uuid);
            next;
        }
    }
}
1;
