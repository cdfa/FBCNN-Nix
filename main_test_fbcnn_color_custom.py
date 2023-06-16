import os.path
import logging
import numpy as np
from collections import OrderedDict
import torch
from utils import utils_logger
from utils import utils_image as util
import requests
from patchify import patchify, unpatchify # todo: maybe without?
import pyexiv2
import math
import itertools


def main():
    testset_name = "custom"
    n_channels = 3  # set 1 for grayscale image, set 3 for color image
    model_name = "fbcnn_color.pth"
    nc = [64, 128, 256, 512]
    nb = 4
    testsets = "testsets"
    results = "test_results"

    result_name = testset_name + "_" + model_name[:-4]
    L_path = os.path.join(testsets, testset_name)
    E_path = os.path.join(results, result_name)  # E_path, for Estimated images
    util.mkdir(E_path)

    model_pool = "model_zoo"  # fixed
    model_path = os.path.join(model_pool, model_name)
    if os.path.exists(model_path):
        print(f"loading model from {model_path}")
    else:
        os.makedirs(os.path.dirname(model_path), exist_ok=True)
        url = "https://github.com/jiaxi-jiang/FBCNN/releases/download/v1.0/{}".format(
            os.path.basename(model_path)
        )
        r = requests.get(url, allow_redirects=True)
        print(f"downloading model {model_path}")
        open(model_path, "wb").write(r.content)

    logger_name = result_name
    utils_logger.logger_info(
        logger_name, log_path=os.path.join(E_path, logger_name + ".log")
    )
    logger = logging.getLogger(logger_name)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    # ----------------------------------------
    # load model
    # ----------------------------------------

    from models.network_fbcnn import FBCNN as net

    model = net(in_nc=n_channels, out_nc=n_channels, nc=nc, nb=nb, act_mode="R")
    model.load_state_dict(torch.load(model_path), strict=True)
    model.eval()
    for k, v in model.named_parameters():
        v.requires_grad = False
    model = model.to(device)
    logger.info("Model path: {:s}".format(model_path))

    test_results = OrderedDict()
    test_results["psnr"] = []
    test_results["ssim"] = []
    test_results["psnrb"] = []

    L_paths = util.get_image_paths(L_path)
    for idx, img in enumerate(L_paths):
        # ------------------------------------
        # (1) img_L
        # ------------------------------------
        img_name, ext = os.path.splitext(os.path.basename(img))
        out_path = os.path.join(E_path, os.path.basename(img))
        logger.info("{:->4d}--> {:>10s}".format(idx + 1, img_name + ext))
        img_L_metadata = pyexiv2.ImageMetadata(img)
        img_L_metadata.read()

        img_L = util.imread_uint(img, n_channels=n_channels)

        img_L_shape = np.asarray(img_L).shape
        img_width = img_L_shape[1]
        img_height = img_L_shape[0]
        max_patch_width = 1990656 / img_height
        min_columns = math.ceil(img_width / max_patch_width)
        for columns in itertools.count(start=min_columns):
            if img_width % columns == 0:
                break

        logger.info("columns: {:d}".format(columns))
        patch_width = math.floor(img_width / columns)
        patches = patchify(img_L, (img_height, patch_width, 3), step=patch_width)

        for i, patch in enumerate(patches[0]):
            patch = patch[0]
            img_L = util.uint2tensor4(patch)
            img_L = img_L.to(device)

            # ------------------------------------
            # (2) img_E
            # ------------------------------------

            # img_E,QF = model(img_L, torch.tensor([[0.6]]))
            img_E, QF = model(img_L)
            QF = 1 - QF
            img_E = util.tensor2single(img_E)
            img_E = util.single2uint(img_E)
            logger.info("predicted quality factor: {:d}".format(round(float(QF * 100))))
            patches[0][i][0] = img_E

        img_E = unpatchify(patches, img_L_shape)

        util.imsave(img_E, out_path)

        img_E_metadata = pyexiv2.ImageMetadata(out_path)
        img_E_metadata.read()
        for key, tag in img_L_metadata.items():
            img_E_metadata[key] = tag.value # todo: raw value for xmp tags?
        
        img_E_metadata.write()


if __name__ == "__main__":
    main()
